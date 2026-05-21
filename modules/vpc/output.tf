output "vpc_id"           { value = aws_vpc.bcsap1.id }
output "public_subnet_a"  { value = aws_subnet.public.id }
output "public_subnet_b"  { value = aws_subnet.public_b.id }
output "private_subnet_a" { value = aws_subnet.private.id }
output "private_subnet_b" { value = aws_subnet.private_b.id }
