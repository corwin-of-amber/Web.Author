
XZ_EMBEDDED_REPO = https://git.tukaani.org/xz-embedded.git


all: workdir
	cd workdir/userspace && wasi-kit make xzminidec

workdir:
	git clone $(XZ_EMBEDDED_REPO) $@

