<domain type='kvm'>
  <name>__VM_NAME__</name>
  <description>__VM_NUM__</description>
  <memory>__VM_MEMSIZE__</memory>
  <currentMemory>__VM_MEMSIZE__</currentMemory>
  <vcpu>__VM_CORE__</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-passthrough'>
  </cpu>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/bin/kvm</emulator>
    <disk type='block' device='disk'>
      <driver name='qemu' cache='none' io='native'/>
      <source dev='__VM_DISKPATH__'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <target dev='hdc' bus='ide'/>
      <readonly/>
    </disk>
    <interface type='bridge'>
      <mac address='__VM_MAC0__'/>
      <source bridge='__BRIDGE0__'/>
      <model type='virtio'/>
      <target dev='__VM_NIC0__'/>
      <bandwidth>
        <inbound average='12500'/>
        <outbound average='12500'/>
      </bandwidth>
    </interface>
    <console type='pty'>
      <target port='0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <input type='tablet' bus='usb'/>
    <graphics type='vnc' port='__VM_VNC__' autoport='no' listen='0.0.0.0' keymap='ja'/>
    <video>
      <model type='vga' vram='1024' heads='1'/>
    </video>
  </devices>
</domain>

