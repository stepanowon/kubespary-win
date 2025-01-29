# 로컬 머신에 멀티노드 k8s 클러스터 만들기

[VirtualBox](https://www.virtualbox.org/)와 [Vagrant](https://www.vagrantup.com/) 최신 버전을 여러개의 VM을 실행할 수 있는 충분한 메모리를 가진 로컬 컴퓨터에 설치합니다. 
* virtualbox는 반드시 확장팩까지 설치합니다.

## 기본 설치 사항
- ubuntu-24.04
- node
  * k8s-master : 192.168.56.201
  * k8s-node1 : 192.168.56.202
  * k8s-node2 : 192.168.56.203
- git  

## vagrant을 이용해서 VM을 설치
```sh
# github repo에서 vagrantfile을 내려받아 설치
git clone https://github.com/stepanowon/kubespray-win
cd kubespray-win
vagrant up

# 설치가 완료된 후 reload
vagrant reload

# 사용자명과 초기 패스워드 : vagrant/asdf  

# virtualbox 확장팩 설치치
sudo apt-get install -y virtualbox-ext-pack
```

## kubespray를 이용한 k8s 설치

### vbox 확장 팩 설치( 모든 노드에서 )
```sh
ssh vagrant@192.168.56.201

# 설치 완료후 재부팅할 것
sudo apt-get install -y virtualbox-ext-pack
sudo reboot now
```

### ssh 설정(k8s-master에서)
```sh
ssh-keygen -t rsa -b 4096

ssh-copy-id vagrant@192.168.56.201
ssh-copy-id vagrant@192.168.56.202
ssh-copy-id vagrant@192.168.56.203
```

### python 가상환경 생성(k8s-master에서)
```sh
sudo apt install -y python3.12-venv

python3 -m venv myenv
source myenv/bin/activate
```

### kubespray git clone 후 설치(k8s-master에서)
```sh
# git clone
cd ~
git clone https://github.com/kubespray/kubespray.git
cd ~/kubespray

# requirements.txt 편집하여 ansible 버전 수정( 9.6.0 ---> 9.6.1 )
vi requirements.txt

ansible==9.6.1
......

# pip로 ansible 및 필요 도구 설치
pip3 install -r requirements.txt

# 샘플 인벤토리 파일 복사
cp -rfp inventory/sample inventory/mycluster

# inventory 설정 파일 변경
vi inventory/mycluster/inventory.ini

[all]
k8s-master ansible_host=192.168.56.201 ip=192.168.56.201
k8s-node1 ansible_host=192.168.56.202 ip=192.168.56.202
k8s-node2 ansible_host=192.168.56.203 ip=192.168.56.203

[kube_control_plane]
k8s-master

[etcd]
k8s-master

[kube_node]
k8s-node1
k8s-node2

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node

# ansible playbook을 이용한 설치(설치 시간 20분 내외)
ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root cluster.yml
```

### kubectl 설정
```sh
# kubeconfig 파일을 로컬 k8s-master의 vagrant 사용자의 홈디렉토리에 복사
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# kubectl 도구가 설치된 다른 컴퓨터를 이용하고 싶다면 ~/.kube/config 파일을 복사하여 사용함

# kubectl 자동완성 기능과 kubectl --> k로 사용하기
sudo apt install bash-completion
source /usr/share/bash-completion/bash_completion

echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc

source ~/.bashrc
```
---
## metalLB 설치 (v0.14.8 기준)

#### 공식문서
https://metallb.universe.tf/installation/


#### kube-proxy의 strictARP 설정값을 true로 변경

```sh
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
```

#### yaml 파일 이용해 metalLB 설치
```sh
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
```

#### 설치된 metalLB 요소 확인
```sh
$ kubectl get all -n metallb-system
NAME                              READY   STATUS    RESTARTS      AGE
pod/controller-6dd967fdc7-jdcgq   1/1     Running   1 (33m ago)   34m
pod/speaker-ftfwm                 1/1     Running   0             34m
pod/speaker-vddww                 1/1     Running   0             34m
pod/speaker-x72gz                 1/1     Running   0             34m

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/metallb-webhook-service   ClusterIP   10.96.10.203   <none>        443/TCP   34m

NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/speaker   3         3         3       3            3           kubernetes.io/os=linux   34m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/controller   1/1     1            1           34m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/controller-6dd967fdc7   1         1         1       34m=
```

#### External IP로 사용할 IP Address Pool 과 L2 Advertisement 설정
```sh
$ cat ~/vagrant/conf/ip-addr-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.56.51-192.168.56.80         #외부에서 접근가능한 IP 대역 지정
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: example
spec:
  ipAddressPools:
  - metallb-ip-pool	    #직전 설정한 ip-pool 객체 지정	
  nodeSelectors:	      # ip-pool을 이용해 접근하는 노드 지정 worker1, worker2 지정
  - matchLabels:
      kubernetes.io/hostname: k8s-node1		
  - matchLabels:
      kubernetes.io/hostname: k8s-node2

$ kubectl apply -f ~/vagrant/conf/ip-addr-pool.yaml
```

#### LoadBalancer 테스트
```sh
$ kubectl apply -f ~/vagrant/conf/deployment.yaml
$ kubectl apply -f ~/vagrant/conf/svc-lb.yaml

$ kubectl get all
$ kubectl get all
NAME                                 READY   STATUS    RESTARTS   AGE
pod/nodeapp-deploy-986b998c4-kdbq8   1/1     Running   0          117s
pod/nodeapp-deploy-986b998c4-qfmjm   1/1     Running   0          117s

NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/kubernetes   ClusterIP      10.96.0.1       <none>          443/TCP        17m
service/nodeapp-lb   LoadBalancer   10.103.201.26   192.168.56.51   80:31966/TCP   105s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nodeapp-deploy   2/2     2            2           117s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/nodeapp-deploy-986b998c4   2         2         2       117s

$ curl http://192.168.56.51
  <div>
    <h2> Version: 1.0.0 </h2>
    <h2> 호스트명 : nodeapp-deploy-986b998c4-qfmjm </h2>
  </div>

$ curl http://192.168.56.51
  <div>
    <h2> Version: 1.0.0 </h2>
    <h2> 호스트명 : nodeapp-deploy-986b998c4-kdbq8 </h2>
  </div>
```

#### 테스트용 deployment, sercice 삭제
```sh
$ kubectl delete -f ~/vagrant/conf/deployment.yaml
$ kubectl delete -f ~/vagrant/conf/svc-lb.yaml
```
---

## Ingress NGINX controller 테스트

[https://kubernetes.github.io/ingress-nginx/deploy/baremetal](https://kubernetes.github.io/ingress-nginx/deploy/baremetal).
#### 미리 설치할 것
* metalLB가 설치되어 있어야 함

#### ingress-nginx-controller 설치
```sh
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

# 설치 확인
$ kubectl get all -n ingress-nginx
NAME                                           READY   STATUS      RESTARTS   AGE
pod/ingress-nginx-admission-create-xwll5       0/1     Completed   0          28s
pod/ingress-nginx-admission-patch-6kp5x        0/1     Completed   1          28s
pod/ingress-nginx-controller-548946fc6-xzs2j   1/1     Running     0          28s

NAME                                         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/ingress-nginx-controller             NodePort    10.110.86.20     <none>        80:30262/TCP,443:32420/TCP   29s
service/ingress-nginx-controller-admission   ClusterIP   10.110.172.255   <none>        443/TCP                      29s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           29s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-548946fc6   1         1         1       29s

NAME                                       STATUS     COMPLETIONS   DURATION   AGE
job.batch/ingress-nginx-admission-create   Complete   1/1           7s         28s
job.batch/ingress-nginx-admission-patch    Complete   1/1           8s         28s
```

#### ingress-nginx-controller의 Service Type을 LoadBalancer로 변경
```sh
# 변경
### Linux
kubectl -n ingress-nginx patch service ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'

### Windows
kubectl -n ingress-nginx patch service ingress-nginx-controller -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'

# 변경후 EXTERNAL-IP 값 확인 (아래 예시에서는 192.168.56.51)
$ kubectl get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.110.86.20     192.168.56.51   80:30262/TCP,443:32420/TCP   5m27s
ingress-nginx-controller-admission   ClusterIP      10.110.172.255   <none>          443/TCP                      5m27s
```

#### Host 컴퓨터 또는 master 노드의 hosts 파일에 EXTERNAL-IP에 대한 hostname 등록
```sh
# 윈도우 : c:\windows\system32\drivers\etc\hosts 파일을 관리자 권한으로 변경
# 리눅스 또는 맥 : sudo vi /etc/hosts
$ sudo vi /etc/hosts
192.168.56.51   demo.example.com
```

#### Service, Deployment 실행
```sh
# nodeapp1.yaml : /path1/* 패턴에 대한 요청 처리 애플리케이션
# nodeapp2.yaml : /path2/* 패턴에 대한 요청 처리 애플리케이션

$ kubectl apply -f ~/vagrant/conf/nodeapp1.yaml
$ kubectl apply -f ~/vagrant/conf/nodeapp2.yaml

# ingress 파일 편집 : host 필드의 값을 앞에서 hosts 파일에 등록한 hostname(demo.example.com) 으로 변경
$ cat ~/vagrant/conf/nodeapp-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: demo.example.com
    http:
      paths:
      - pathType: ImplementationSpecific
        path: /path1(/|$)(.*)
        backend:
          service:
            name: svc-nodeapp1
            port:
              number: 8080
      - pathType: ImplementationSpecific
        path: /path2(/|$)(.*)
        backend:
          service:
            name: svc-nodeapp2
            port:
              number: 8080

# ingresss 적용하기
$ kubectl apply -f ~/vagrant/conf/nodeapp-ingress.yaml
```

#### hosts 파일을 등록한 Host 또는 master 노드에서 다음과 같이 요청해보기
```sh
$ curl http://demo.example.com/path1/abc
  <div style="background-color:aqua">
    <h2> nodeapp-path1</h2>
    <h2> 호스트명 : nodeapp-path1-84c8cb66df-zglw2 </h2>
    <h2> 요청경로 : abc </h2>
  </div>

$ curl http://demo.example.com/path2/abc
  <div style="background-color:yellow">
    <h2> nodeapp-path2</h2>
    <h2> 호스트명 : nodeapp-path2-7c48f69bb5-x6rkm </h2>
    <h2> 요청경로 : abc </h2>
  </div>
```

#### 리소스 삭제
```sh
kubectl delete -f ~/vagrant/conf/nodeapp1.yaml
kubectl delete -f ~/vagrant/conf/nodeapp2.yaml
kubectl delete -f ~/vagrant/conf/nodeapp-ingress.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml

```



