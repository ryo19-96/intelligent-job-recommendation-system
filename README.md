# intelligent-job-recommendation-system

## 概要
求職者が会話ベースでAIエージェントとやりとりを行い求人を探すことが出来るシステム。  
APIで取得した求人データを内容によってRDB, Vector DB, Knowledge Graphに保存。各MCPサーバーを立ててAIエージェントがやり取りを行えるようにする。  
求人データは1日に1回取得する。
クラウド: google cloud
インフラ管理: terraform
LLM評価・監視:  Langfuse


## 使用データ

本プロジェクトでは以下のデータを利用しています：

1. **求人データ**
   - 出典：しごとナビ
   - URL：https://www.shigotonavi.co.jp/
   - 内容：求人情報のデータ（下記参照）


### APIで以下のようなデータを得られる
（nullになるものも多い）
| パラメーター名 | 内容                                        |
| :------------- | :------------------------------------------ |
| url            | 求人情報詳細ページのURL                     |
| url_mob        | 求人情報詳細ページのURL(しごとナビモバイル) |
| url_sp         | 求人情報詳細ページのURL(しごとナビスマホ)   |
| companyname    | 求人会社名（社名非公開の場合は会社の特徴）  |
| jobtypedetail  | 職種名                                      |
| businessdetail | 業務内容                                    |
| salary_y_min   | 年収下限                                    |
| salary_y_max   | 年収上限                                    |
| salary_m_min   | 月給下限                                    |
| salary_m_max   | 月給上限                                    |
| salary_d_min   | 日給下限                                    |
| salary_d_max   | 日給上限                                    |
| salary_h_min   | 時給下限                                    |
| salary_h_max   | 時給上限                                    |
| workingtype    | 勤務形態                                    |
| workingplace   | 勤務地                                      |
| workingtime    | 勤務時間                                    |
| schooltype     | 応募可能学歴                                |
| pr1_title      | 求人情報PRタイトル1                         |
| pr1_body       | 求人情報PR内容1                             |
| pr2_title      | 求人情報PRタイトル2                         |
| pr2_body       | 求人情報PR内容2                             |
| pr3_title      | 求人情報PRタイトル3                         |
| pr3_body       | 求人情報PR内容3                             |

内容によって各データベースに保存する

### データの配置と重複設計

| データ項目                        |           RDB            |        Vector DB         |     Knowledge Graph      | 重複理由・用途の違い                                                                                                                    |
| --------------------------------- | :----------------------: | :----------------------: | :----------------------: | --------------------------------------------------------------------------------------------------------------------------------------- |
| url系（url / url\_mob / url\_sp） |    :white_check_mark:    | :heavy_multiplication_x: | :heavy_multiplication_x: | メタデータ的性質<br>アクセス頻度が低く他 DB での用途なし                                                                                |
| companyname                       |    :white_check_mark:    | :heavy_multiplication_x: |    :white_check_mark:    | 正規化された企業名 (company\_id, clean\_name)<br>RDB: 企業別集計・検索<br>KG: 企業–業界–求人 関係性<br>Vector: 不要（メタデータで十分） |
| jobtypedetail                     |    :white_check_mark:    |    :white_check_mark:    |    :white_check_mark:    | RDB: カテゴリ分類・集計<br>Vector: セマンティック検索（埋め込みに含める）<br>KG: JobRole ノードでキャリアパス分析                       |
| businessdetail                    | :heavy_multiplication_x: |    :white_check_mark:    |    :white_check_mark:    | Vector: セマンティック検索のメイン対象<br>KG: スキル・業務の関係性抽出<br>RDB: 検索用途がないため保持しない                             |
| salary\_y\_min / max              |    :white_check_mark:    | :heavy_multiplication_x: |    :white_check_mark:    | RDB: 高速範囲検索・インデックス最適化<br>KG: 市場分析・推薦理由説明<br>Vector: 不要                                                     |
| workingtype                       |    :white_check_mark:    | :heavy_multiplication_x: |    :white_check_mark:    | RDB: 雇用形態フィルタ<br>KG: 雇用形態–キャリアパス関係                                                                                  |
| workingplace                      |    :white_check_mark:    | :heavy_multiplication_x: |    :white_check_mark:    | RDB: 地域フィルタリング（県・市・区階層）<br>KG: 地域特性・産業集積分析                                                                 |
| worktime                          |    :white_check_mark:    | :heavy_multiplication_x: | :heavy_multiplication_x: | 単純属性情報（主にフィルタ用途）                                                                                                        |
| schooltype                        |    :white_check_mark:    | :heavy_multiplication_x: |    :white_check_mark:    | RDB: 学歴要件フィルタ<br>KG: 学歴–職種–スキル関係性                                                                                     |
| pr1\_title / body                 | :heavy_multiplication_x: |    :white_check_mark:    |    :white_check_mark:    | Vector: 企業文化のセマンティック検索<br>KG: 業界分類・企業特徴の説明                                                                    |
| pr2\_title / body                 | :heavy_multiplication_x: |    :white_check_mark:    |    :white_check_mark:    | Vector: 「コミュ力重視」等の検索<br>KG: 人物像–スキル–職種関係                                                                          |
| pr3\_title / body                 | :heavy_multiplication_x: |    :white_check_mark:    |    :white_check_mark:    | Vector: 「ワークライフバランス」検索<br>KG: 福利厚生レベル–企業規模関係                                                                 |

### データベース別データ量と性能要件
| データベース    | 保存データ量                                   | 主要用途                                     | パフォーマンス要件                |
| --------------- | ---------------------------------------------- | -------------------------------------------- | --------------------------------- |
| RDB             | 中程度（基本属性のみ・長文テキストなし）       | 高速フィルタリング / 集計・統計 / OLTP       | 10–50 ms クエリ応答、同時検索多数 |
| Vector DB       | 大容量（全テキスト埋め込み・768 次元ベクトル） | セマンティック検索 / 類似求人発見 / 曖昧検索 | 100–300 ms 高精度検索             |
| Knowledge Graph | 中程度（関係性中心・推論用メタデータ）         | 関係性分析 / 推薦理由説明 / キャリアパス探索 | 50–200 ms 複雑トラバーサル        |

