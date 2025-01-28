# 로컬 머신에 멀티노드 k8s 클러스터 만들기

[VirtualBox](https://www.virtualbox.org/)와 [Vagrant](https://www.vagrantup.com/) 최신 버전을 여러개의 VM을 실행할 수 있는 충분한 메모리를 가진 로컬 컴퓨터에 설치합니다. 
* virtualbox는 반드시 확장팩까지 설치합니다.

## 기본 설치 사항
- ubuntu-24.04
- node
  * vm1 : 192.168.56.201
  * vm2 : 192.168.56.202
  * vm3 : 192.168.56.203
- git  

## vagrant을 이용해서 VM을 설치
```sh
# github repo에서 vagrantfile을 내려받아 설치
git clone https://github.com/stepanowon/kubespray-win
cd kubespray-win
vagrant up

# 설치가 완료된 후 reload
vagrant reload

# 사용자명과 초기 패스워드 : user1/asdf
```
