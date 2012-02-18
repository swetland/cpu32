# Copyright 2012, Brian Swetland

# to run: quartus_stp -t download.tcl

# find programmer and device
foreach hardware_name [get_hardware_names] {
	if { [string match "USB-Blaster*" $hardware_name] } {
		set usbblaster_name $hardware_name
	}
}
puts "Bridge: $usbblaster_name";
foreach device_name [get_device_names -hardware_name $usbblaster_name] {
	if { [string match "@1*" $device_name] } {
		set test_device $device_name
	}
}
puts "Device: $test_device";
open_device -hardware_name $usbblaster_name -device_name $test_device

device_lock -timeout 10000

device_ir_shift -ir_value 6 -no_captured_ir_value
puts "IDCODE: 0x[device_dr_shift -length 32 -value_in_hex]"

proc xmit_vdr { len val } {
	device_virtual_dr_shift -instance_index 0 -length $len -dr_value $val -value_in_hex -no_captured_dr_value
}

proc xmit_vir { val } {
	device_virtual_ir_shift -instance_index 0 -ir_value $val -no_captured_ir_value
}

set IR_CTRL 0
set IR_ADDR 1
set IR_DATA 2

xmit_vir $IR_CTRL
xmit_vdr 32 00000001

xmit_vir $IR_ADDR
xmit_vdr 32 00000000

xmit_vir $IR_DATA
set fp [open "test.hex" r]
while { [gets $fp line] > 0 } {
	set val [lindex [split $line] 0]
	set val [format "%08x" 0x$val]
#	puts $val
	xmit_vdr 32 $val
}
close $fp

xmit_vir $IR_CTRL
xmit_vdr 32 00000000

device_unlock
close_device
