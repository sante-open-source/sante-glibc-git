#!/bin/bash -e
arch=$1
case $arch in
	aarch64)
		target=aarch64-sante-linux-gnu ;;
	x86_64)
		target=x86_64-sante-linux-gnu ;;
	powerpc)
                target=powerpc-sante-linux-gnu ;;
	*)
		echo "Unsupported arch: $arch"
		exit 1
esac
toolchain_prefix=$HOME/dist/$target-gcc/$target-gcc-git
export PATH="$PATH:$toolchain_prefix/bin"

# Clone linux, binutils, gcc and glibc
urls=(git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
      git://sourceware.org/git/binutils-gdb.git
      git://gcc.gnu.org/git/gcc.git
      git://sourceware.org/git/glibc.git)
for url in "${urls[@]}"; do
	git clone --depth=1 "$url" &> /dev/null
done

# Install linux headers
cd linux
make ARCH=$(echo $target | cut -d '-' -f 1) INSTALL_HDR_PATH=$toolchain_prefix headers_install

# Build binutils and gdb
cd .. && mkdir binutils-gdb-build && cd binutils-gdb-build
../binutils-gdb/configure --target=$target \
	                  --prefix=$toolchain_prefix \
		          --disable-multilib
make -j`nproc`
make install

# Build gcc (stage 1)
cd ../gcc
./contrib/download_prerequisites
cd .. && mkdir build-gcc && cd build-gcc
../gcc/configure --target=$target \
	         --prefix=$toolchain_prefix \
		 --enable-languages=c,c++ \
		 --disable-multilib
make -j`nproc` all-gcc
make install-gcc

# Build glibc (stage 1)
cd .. && mkdir build-glibc && cd build-glibc
../glibc/configure --target=$target \
	           --host=$target \
		   --build=x86_64-linux-gnu \
	           --prefix=$toolchain_prefix \
		   --disable-multilib \
		   --with-headers=$toolchain_prefix/include \
		   --without-selinux \
		   libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make -j`nproc` csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o $toolchain_prefix/lib
$target-gcc -nostdlib -nostartfiles -shared -xc /dev/null -o $toolchain_prefix/lib/libc.so
touch $toolchain_prefix/include/gnu/stubs.h

# Build gcc (stage 2)
cd ../build-gcc
make -j`nproc` all-target-libgcc
make install-target-libgcc

# Build glibc (stage 2)
cd ../build-glibc
make -j`nproc`
make install

# Build libstdc++
cd ../build-gcc
make -j`nproc`
make install
ls $toolchain_prefix/bin
