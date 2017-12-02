# tala-infra
ServerSide Scripts

```
opt/tala/
|   bin
    |   bmgetinfo.sh  : BMサーバ情報取得コマンド(大体10~20分くらいかかる)
    |   bmcreate.sh   : BMサーバ構築コマンド(大体 5分くらいかかる)
    |   kvmcreate.sh  : BMサーバをKVMホストとしてセットアップするコマンド(大体 5分くらいかかる)
    |   vmdeploy.sh   : VMを作成するコマンド。対象となるKVMホストはWEBGUIで決まる。vmcreate.shのラッパー
    |   vmdestroy.sh  : VMを削除するコマンド。対象となるKVMホストはWEBGUIで決まる。vmremove.shのラッパー
    |   condeploy.sh   : コンテナを作成するコマンド。対象となるDockerホストはWEBGUIで決まる。concreate.shのラッパー
    |   condestroy.sh  : コンテナを削除するコマンド。対象となるDockerホストはWEBGUIで決まる。convmremove.shのラッパー
    |   power.sh      : Nodes/VMs/Containersの電源情報の取得及び電源ステータスの変更を行うコマンド
    |   common.cfg  : 各コマンド共通で利用する関数など
    |   zabbixapi.sh  : Zabbix連携で利用するコマンド。
    --- live  : 各live image　で実行されるコマンド置き場
         |   osinstall.sh.tpl : deploy イメージが取得し実行するコマンド bmcreate.shにより tplから実ファイルが作成される仕組み
         |   getinfo.sh    : getinfo imageが取得し、実行するコマンド
    --- kvm  KVMホスト上で実行されるもの
         |   bm2kvm.sh : kvmcreate.sh 越しにこのコマンドを叩いてセットアップを実行している
         |   libvirtxml.tpl : xmlファイルをdefine することによりVMを認識する仕組み
         |   qemu  : VM起動/停止時にinterfaseの設定を動的に変更するように修正
         |   vmcreate.sh : VMを作成するコマンド(容量次第だが3～5分くらい)
         |   vmremove.sh : VMを削除するコマンド
    --- docker
         |   bm2docker.sh  : ベアメタルをdoxkerホストに変更するコマンド
         |   concreate.sh  : コンテナを作成するコマンド
         |   conpower.sh   : コンテナのpower情報を取得する[(power.shはコイツをたたく)
         |   conremove.sh  : コンテナを削除するコマンド
         |   dockerfile    : OSごとの Dockerfileを設定
         ---- docker
               |  ubuntu1404  初期設定を記載したDockerfile
               |  ubuntu1604  初期設定を記載したDockerfile
|   lock   : 各コマンドが実行される際に、重複が起きないようにlockを入れる。
|   log     : 各コマンドの実行ログが出力される。ここにはBMで実行される初期セットアップのログも転送される
|   nodes : BMnode毎に取得した info情報を格納するDIr
```

```
■DeployServerで実行されるコマンド実行例
▼BM 情報取得
bash /opt/tala/bin/bmgetinfo.sh -H [ID]
▼ベアメタル作成
bash /opt/tala/bin/bmcreate.sh -H [ID] 
↑bmgetinfo.shが実行されていない場合は強制終了

▼BM→KVMホスト化
bash /opt/tala/bin/kvmcreate.sh -H [ID]
▼VM作成
bash /opt/tala/bin/vmdeploy.sh -H [ID]
↑これはラッパーで実際の作成は KVMホスト上のvmcreate.shが実行される
  APIより実行対象サーバのIPアドレスやVMの情報を入手する
▼VM削除
bash /opt/tala/bin/vmdestroy.sh -H [ID]
↑これはラッパーで実際の作成は KVMホスト上のvmremove.shが実行される


▼BM→Dockerホスト化
bash /opt/tala/bin/dockercreate.sh -H [ID]
▼コンテナ作成
bash /opt/tala/bin/condeploy.sh -H [ID]
↑これはラッパーで実際の作成は KVMホスト上のconcreate.shが実行される
  APIより実行対象サーバのIPアドレスやVMの情報を入手する
▼コンテナ削除
bash /opt/tala/bin/condestroy.sh -H [ID]
↑これはラッパーで実際の作成は KVMホスト上のvmremove.shが実行される


▼電源状態の取得/変更
bash /opt/tala/bin/power.sh -H [ID] -O [on/off/restart/status] -T [vm/bm/container]


■KVMホスト上で実行
▼KVMホスト化
bash /opt/tala/bin/bm2kvm.sh
▼VM作成
bash /opt/tala/bin/vmcreate.sh [-n guest_machine_name] [-c cpu_core] [-m vm_memory_size] [-d vm_hdd_size] [-p md5_password] [-o distribution] [-r] 
▼VM削除
bash /opt/tala/bin/vmremove.sh [-n guest_machine_name]

■Dockerホスト上で実行
▼Dockerホスト化
bash /opt/tala/bin/bm2docker.sh
▼Container作成
bash /opt/tala/bin/concreate.sh [-n guest_machine_name] [-p md5_password] [-o distribution] [-r] 


■Zabbix API越しもろもろの連携を行う
bash /opt/tala/bin/zabbixapi.sh
```
