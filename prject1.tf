// provider 
provider "aws" {
	region = "ap-south-1"
	profile = "yashterra"
}

//key-pair creation
resource "aws_key_pair" "testkey" {
	public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAibNxdwrZpAS2utO64Swo5Nn4dgwYawGhw3sfWbNqP9ondgglMohEGLIZOYDxLHfLYtC+e5LB7EcJCyXr1KD/hFt+SlRfXm0c9wRPR6vP9+SZFAY2lwlNZRjMcsW0+Thd9ftFMjZO/QzRGt4B02G9dL6DvqLYhXYPfpG5mXe87WsGHOyF+6NwET2Hj9GwhiJdNn7+v6cKzGJyJDH0xHpeuFVMhMEXfFAS9NHyyofXEhCut3RT3DkiPHwIklZbc+yVkO5Ft2slBq1dE59b0/axMqT/3RUKxz9gpEPQvq9sdIg5Fww1IJ2FhHL03Cr4fJ5lPo41G9TOx/6ZHlJ/5xDb4w== rsa-key-20200611"
}

output "key_name" {
	value = aws_key_pair.testkey.key_name
}

//security-group creation
resource "aws_security_group" "httpd" {
  name        = "httpd"
  description = "Allow 80 , 8080 and 22 ports inbound traffic"
  vpc_id      = "vpc-d4f7eabc"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//s3-bucket creation
variable "enter_bucket_name" {
	type = string
}

resource "aws_s3_bucket" "trailbucket" {
  bucket = var.enter_bucket_name
  acl = "public-read"
  
}

resource "aws_s3_bucket_public_access_block" "bucketaccess" {
  bucket = var.enter_bucket_name
}


output "cf1" {
 	value =  aws_s3_bucket.trailbucket.bucket_domain_name
}

output "cfs3" {
	value = aws_s3_bucket.trailbucket.id
}

//cloud-front creation
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {

}

output "origin" {
	value = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.trailbucket.bucket_domain_name
    origin_id   = aws_s3_bucket.trailbucket.id
    
    custom_origin_config {
         http_port = 80
         https_port = 80
         origin_protocol_policy = "match-viewer"
         origin_ssl_protocols = ["TLSv1"  , "TLSv1.1" , "TLSv1.2"]
         }
    
    
  }

  enabled             = true
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.trailbucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfrontdomain" {
	value = aws_cloudfront_distribution.s3_distribution.domain_name
}

 resource "null_resource" "cloudfrontdomain" {
      depends_on = [ aws_cloudfront_origin_access_identity.origin_access_identity
	] 
	provisioner "local-exec" {
	   command = "echo ${aws_cloudfront_distribution.s3_distribution.domain_name}  > cloudfrontdomain.txt" 
  }
} 
//creating instance
resource "aws_instance"  "webpage" {
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.testkey.key_name
  security_groups = [ "httpd" ]
}

output "zone" {
	value = aws_instance.webpage.availability_zone
}

output "id" {
	value = aws_instance.webpage.id
}

output "publicip" {
	value = aws_instance.webpage.public_ip
}

resource "null_resource" "public_ip" {
  provisioner "local-exec" {
	command = "echo ${aws_instance.webpage.public_ip} > publicip.txt"
  }
} 

//creating volume
resource "aws_ebs_volume" "example" {
  availability_zone = aws_instance.webpage.availability_zone
  size              = 1
}

output "volume_credentials_1" {
	value = aws_ebs_volume.example.id
}

//Attaching volume to the instance
resource "aws_volume_attachment" "ebs_att_inst" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.webpage.id
  force_detach = true
}


resource "null_resource" "softwares" {
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/yasu/Desktop/keyfinal.pem")
    host     = aws_instance.webpage.public_ip
  }

  provisioner "remote-exec" {
    inline = [ "sudo yum install docker -y", 
	  "sudo yum install httpd -y",
	 " sudo systemctl start httpd",
	  "sudo systemctl enable httpd",
	  "sudo systemctl start docker",
	  "sudo systemctl enable docker",
	  ]
  }
}
 

resource "null_resource" "volumeformat" {
  depends_on = [
	aws_volume_attachment.ebs_att_inst
	]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/yasu/Desktop/keyfinal.pem")
    host     = aws_instance.webpage.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
    ]
  }
}
 	
resource "null_resource" "jenkins" {
    depends_on = [
	      null_resource.softwares
	]
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/yasu/Desktop/keyfinal.pem")
    host     = aws_instance.webpage.public_ip
  }

   provisioner "remote-exec" {
      inline = [
	"sudo docker pull yashwanth3/yashjenkins",
	"sudo docker run -dit --name jen1 --privileged --init -v /:/baseos -p 8080:8080  yashwanth3/yashjenkins",
	"sudo docker exec jen1 yum install git -y"
	]
  }
}


