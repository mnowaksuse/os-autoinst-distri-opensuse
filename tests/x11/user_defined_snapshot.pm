# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Show user defined comments in grub2 menu for snapshots
# Maintainer: Dumitru Gutu <dgutu@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;

sub y2snapper_create_snapshot {
    my ($self, $name, $user_data) = @_;
    $name      //= 'grub_comment';
    $user_data //= 'bootloader="Bootloader_Comment"';
    # Open the 'C'reate dialog and wait until it is there
    send_key "alt-c";
    assert_screen 'yast2_snapper-createsnapshotdialog', 100;
    # Fill the form and finish by pressing the 'O'k-button
    type_string $name;
    send_key "alt-u";    # match User data column
    type_string $user_data;
    save_screenshot;
    send_key "alt-o";
    save_screenshot;
}

sub run {
    my $self = shift;
    select_console 'x11';
    # Start an xterm as root
    x11_start_program('xterm');
    become_root;
    script_run "cd";

    # Start the yast2 snapper module and wait until it is started
    type_string "yast2 snapper\n";
    assert_screen 'yast2_snapper-snapshots', 100;
    # ensure the last screenshots are visible
    send_key 'end';
    # Make sure the test snapshot is not there
    die("Unexpected snapshot found") if (check_screen([qw(grub_comment)], 1));

    # Create a new snapshot
    $self->y2snapper_create_snapshot();
    # Make sure the snapshot is listed in the main window
    send_key_until_needlematch([qw(grub_comment)], 'pgdn');
    # C'l'ose  the snapper module
    send_key "alt-l";
    power_action('reboot', keepconsole => 1, textmode => 1);

    if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
        console('svirt')->suspend;
        select_console 'svirt';
        console('svirt')->resume;
        wait_serial('Press enter to boot the selected OS') || die 'GRUB did not appear on serial console';
        # Here we leverage environmental variable 'pty' set by bootloaded_svirt
        #type_string "echo \$pty\n";
        type_string "echo -en '\\033[C' > \$pty\n";    # right (enter sub menu)
        type_string "echo -en '\\033[A' > \$pty\n";    # up (stop GRUB count down)
        wait_serial('Advanced options for SLES', 10) || die 'Menu from disk did not apper';
        type_string "echo -en '\\033[K' > \$pty\n";    # end
        wait_serial('Start bootloader from a read-only snapshot', 10) || die 'Pointer was not placed on "read-only snapshot" line';
        type_string "echo -en '\\033[C' > \$pty\n";    # right (enter sub menu)
        wait_serial('Bootloader_Comment', 10) || die 'Menu with line "(Bootloader_Comment)" did not appear';
        type_string "echo -en '\\033[C' > \$pty\n";    # right (confirm item)
        wait_serial('Bootable snapshot', 10) || die 'Pointer was not placed on "Bootable snapshot" line';
        type_string "echo -en '\\033[C' > \$pty\n";    # right (confirm item)
        select_console 'sut';
    }
    else {
        $self->handle_uefi_boot_disk_workaround() if get_var('MACHINE') =~ qr'aarch64';
        assert_screen "grub2";
        send_key 'up';

        send_key_until_needlematch("boot-menu-snapshot", 'down', 10, 5);
        send_key 'ret';

        # On slow VMs we press down key before snapshots list is on screen
        wait_screen_change { assert_screen 'boot-menu-snapshots-list' };

        send_key_until_needlematch("snap-bootloader-comment", 'down', 10, 5);
        save_screenshot;
        wait_screen_change { send_key 'ret' };
        # boot into the snapshot
        # do not try to search for the grub menu again as we are already here
    }
    $self->wait_boot(textmode => 1, in_grub => 1);
    # request reboot again to ensure we will end up in the original system
    send_key 'ctrl-alt-delete';
    power_action('reboot', keepconsole => 1, textmode => 1, observe => 1);
    $self->wait_boot;
}
#sub post_fail_hook { diag 'sleep'; sleep; }
sub post_fail_hook { }
1;
