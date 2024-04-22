output vpc_id {
    value = aws_vpc.main.id
}

output bastion_subnet_id {
    value = element(aws_subnet.public_subnet.*.id,0)
}

output priv_subnet_id {
    value = element(aws_subnet.private_subnet.*.id,0)
}

output bastion_security_group_id {
    value = aws_security_group.bastion.id
}

output private_security_group_id {
    value = aws_security_group.private.id
}

output app_security_group_id {
    value = aws_security_group.public.id
}

output public_subnet_id {
    value = aws_subnet.public_subnet.*.id
}

output priv_subnet_id_list {
    value = aws_subnet.private_subnet.*.id
}

output pub_subnet_id_list {
    value = aws_subnet.public_subnet.*.id
}