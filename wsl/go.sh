cd ~/software
# 下载安装
wget https://mirrors.aliyun.com/golang/go1.24.3.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.zshrc
source ~/.zshrc

go version


# 设置国内代理
go env -w GO111MODULE=on
go env -w GOPROXY=https://goproxy.cn,direct