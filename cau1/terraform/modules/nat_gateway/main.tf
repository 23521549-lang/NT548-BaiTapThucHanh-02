locals { name_prefix = "${var.project_name}-${var.environment}" }

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id
  tags          = { Name = "${local.name_prefix}-nat-gw" }
  depends_on    = [aws_eip.nat]
}
