output bastion_ip {
    value = aws_instance.bastion.public_ip
}

output private_ips {
    value = "Jenkins ip : ${aws_instance.jenkins.private_ip} \n"
}