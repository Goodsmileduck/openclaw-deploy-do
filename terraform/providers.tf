provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.spaces_access_key_id != "" ? var.spaces_access_key_id : null
  spaces_secret_key = var.spaces_secret_access_key != "" ? var.spaces_secret_access_key : null
}
