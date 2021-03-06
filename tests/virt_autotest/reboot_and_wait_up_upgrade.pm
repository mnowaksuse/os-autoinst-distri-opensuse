# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use testapi;
use base "reboot_and_wait_up";

sub run() {
    my $self    = shift;
    my $timeout = 3600;
    set_var("reboot_for_upgrade_step", "yes");
    $self->reboot_and_wait_up($timeout);
}

1;

