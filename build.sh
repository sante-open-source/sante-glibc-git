#!/bin/bash -e
arch=$1
case $arch in
	aarch64)
		target=aarch64-sante-elf ;;
	x86_64)
		target=x86_64-sante-elf ;;
	powerpc)
                target=powerpc-sante-elf ;;
	*)
		echo "Unsupported arch: $arch"
		exit 1
esac
toolchain_prefix=$HOME/dist/$target-sante-elf-gcc/$target-sante-elf-gcc-git
export PATH="$PATH:$toolchain_prefix/bin"
git clone --depth=1 git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git &> /dev/null
cd linux
make ARCH=$(echo $target | cut -d '-' -f 1) INSTALL_HDR_PATH=$toolchain_prefix headers_install
cd .. && rm -rf linux
git clone --depth=1 git://sourceware.org/git/binutils-gdb.git &> /dev/null
mkdir binutils-gdb-build && cd binutils-gdb-build
../binutils-gdb/configure --target=$target \
	                  --prefix=$toolchain_prefix \
		          --disable-nls \
make -j`nproc`
make install
cd .. && rm -rf binutils-gdb
git clone --depth=1 git://gcc.gnu.org/git/gcc.git &> /dev/null
cd gcc
./contrib/download_prerequisites
cd .. && mkdir build-gcc && cd build-gcc
../gcc/configure --target=$target \
	         --prefix=$toolchain_prefix \
		 --disable-nls \
		 --disable-multilib \
		 --without-headers \
		 --with-newlib
make -j`nproc` all-gcc all-target-libgcc
make install-gcc install-target-libgcc
cd ..
git clone --depth=1 git://sourceware.org/git/glibc.git &> /dev/null
mkdir build-glibc && cd build-glibc
../glibc/configure --target=$target \
	           --prefix=$toolchain_prefix \
		   --disable-nls \
		   --with-headers=$toolchain_prefix/include \
		   --without-selinux
make -j`nproc`
make install
cd ../build-gcc
rm -rf *
../gcc/configure --target=$target \
	         --prefix=$toolchain_prefix \
		 --enable-languages=c,c++ \
		 --disable-nls \
		 --disable-multilib
make -j`nproc`
make install
ls $toolchain_prefix/bin
