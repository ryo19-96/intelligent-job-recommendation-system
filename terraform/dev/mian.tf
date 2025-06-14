terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=5.33.0"
    }
  }
}

provider "aws" {
  region = "asia-northeast1-a"
}
