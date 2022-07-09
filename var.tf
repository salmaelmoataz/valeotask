variable "region" {
     description = "Region of AWS VPC"
}
variable "name" {
  default = "myadmin"
  type = string
  description = "The name of the user"
}
variable "value" {
  type = string
  description = "range of cidr for waf"
}