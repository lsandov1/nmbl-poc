# SPDX-License-Identifier: GPLv3
#
# Makefile
# Copyright Peter Jones <pjones@redhat.com>
#

TOPDIR ?= $(realpath ./)
include $(TOPDIR)/utils.mk

MOCK_ROOT_NAME ?= $(OS_NAME)-$(OS_VERSION)-$(ARCH)
MOCK_ROOT_PATH ?= $(abspath $(shell mock -r "$(MOCK_ROOT_NAME)" --print-root-path)/../)
DEPLOY_HOST ?= nmbl

all: rpm

dracut-nmbl-$(VERSION).tar.xz :
	$(MAKE) -C dracut-nmbl tarball
	mv -v dracut-nmbl/dracut-nmbl-$(VERSION).tar.xz .

dracut-nmbl-$(VR).src.rpm : dracut-nmbl.spec dracut-nmbl-$(VERSION).tar.xz
	rpmbuild $(RPMBUILD_ARGS) -bs $<

dracut-nmbl-$(VR).noarch.rpm : dracut-nmbl-$(VR).src.rpm
	mock -r "$(MOCK_ROOT_NAME)" --rebuild dracut-nmbl-$(VR).src.rpm
	mv "$(MOCK_ROOT_PATH)/result/$@" .

nmbl-builder-$(VERSION).tar.xz :
	$(MAKE) -C nmbl-builder tarball
	mv -v nmbl-builder/nmbl-builder-$(VERSION).tar.xz .

nmbl-builder-$(VR).src.rpm : nmbl-builder.spec nmbl-builder-$(VERSION).tar.xz
	rpmbuild $(RPMBUILD_ARGS) -bs $<

nmbl-$(KVRA).rpm: nmbl-builder-$(VR).src.rpm dracut-nmbl-$(VR).noarch.rpm
	mock -r "$(MOCK_ROOT_NAME)" --install dracut-nmbl-$(VR).noarch.rpm --cache-alterations --no-cleanup-after
	mock -r "$(MOCK_ROOT_NAME)" --installdeps nmbl-builder-$(VR).src.rpm --cache-alterations --no-clean --no-cleanup-after
	mock -r "$(MOCK_ROOT_NAME)" --rebuild nmbl-builder-$(VR).src.rpm --no-clean
	mv -v "$(MOCK_ROOT_PATH)/result/$@" .

rpm: nmbl-$(KVRA).rpm

install: nmbl-$(KVRA).rpm
	sudo rpm -Uvh nmbl-$(KVRA).rpm

delete_efi_entry:
	efibootmgr -q -b $(EFI_BOOTNUM) -B || true

install_efi_entry:
	echo -n "\n$(EFI_UKI_FILE) quiet boot=$(awk '/ \/boot / {print $1}' /etc/fstab) rd.systemd.gpt_auto=0" \
	| iconv -f UTF8 -t UCS-2LE \
	| efibootmgr -b $(EFI_BOOTNUM) -C -d /dev/vda -p 1 -L $(EFI_LABEL) -l $(EFI_LOADER) -@ - -n $(EFI_BOOTNUM)

deploy: nmbl-$(KVRA).rpm
	scp $< "root@$(DEPLOY_HOST):"
	ssh "root@$(DEPLOY_HOST)" ./deploy.sh "$<"

init-mock:
	mock -r "$(MOCK_ROOT_NAME)" --init

clean-mock:
	mock -r "$(MOCK_ROOT_NAME)" --clean

clean:
	rm -vf $(wildcard *.tar *.tar.xz *.rpm *.spec)

vars:
	$(foreach v, $(.VARIABLES), $(info $(v) = $($(v))))

.PHONY: all clean clean-mock init-mock deploy rpm

# vim:ft=make
