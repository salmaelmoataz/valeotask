provider "aws" {
      region = var.region
}

resource "aws_iam_user" "user" {

  name = var.name
}

resource "aws_iam_access_key" "user_access_key" {

  user       = var.name
  depends_on = [aws_iam_user.user]
}

resource "aws_iam_user_policy" "lb_ro" {
  name = "test1valeo"
  user = var.name
  depends_on = [aws_iam_user.user]

  policy = file("policyforuser.json")

}

resource "aws_waf_ipset" "ipset" {
  name = "tfIPSet"

  ip_set_descriptors {
    type  = "IPV4"
    value = "192.168.0.0/22"
  }
}

resource "aws_waf_rule" "wafrule" {
  depends_on  = [aws_waf_ipset.ipset]
  name        = "tfWAFRule"
  metric_name = "tfWAFRule"

  predicates {
    data_id = aws_waf_ipset.ipset.id
    negated = false
    type    = "IPMatch"
  }
}

resource "aws_waf_web_acl" "waf_acl" {
  depends_on = [
    aws_waf_ipset.ipset,
    aws_waf_rule.wafrule,
  ]
  name        = "tfWebACL"
  metric_name = "tfWebACL"

  default_action {
    type = "BLOCK"
  }

  rules {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id  = aws_waf_rule.wafrule.id
    type     = "REGULAR"
  }
}

resource "aws_iam_policy" "policy" {
  
  name        = "test-policy"
  policy      = file("lam.json")
}

resource "aws_iam_role" "iam_for_lambda" {
  
  name               = "test1valeo"
  assume_role_policy = file("lambdapolicy.json")
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_lambda_function" "test_lambda" {

  filename      = "lmdafnc.zip"
  function_name = "test1valeo"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"

  source_code_hash = filebase64sha256("lmdafnc.zip")

  runtime = "nodejs12.x"
  publish = true

  }


resource "aws_s3_bucket" "b" {
  bucket = "test11valeo"
  acl    = "public-read"
  policy = file("policy.json")

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "log/"

    tags = {
      rule      = "log"
      autoclean = "true"
    }

    expiration {
      days = 365
    }
  }

  versioning {
    enabled = true
  }

  website {
    index_document = "index.html"
    error_document = "error.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
  }

}


locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "example" {
  comment = "Some comment"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.example.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 43200
    default_ttl            = 43200
    max_ttl                = 43200

     lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = "${aws_lambda_function.test_lambda.arn}:${aws_lambda_function.test_lambda.version}"
      include_body = true
    }

  }

  web_acl_id = aws_waf_web_acl.waf_acl.id
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
