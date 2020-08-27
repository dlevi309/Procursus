ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += sqlite3
SQLITE3_FORMAT_V := 3320300
SQLITE3_VERSION  := 3.32.3
DEB_SQLITE3_V    ?= $(SQLITE3_VERSION)

sqlite3-setup: setup
	wget -q -nc -P $(BUILD_SOURCE) http://deb.debian.org/debian/pool/main/s/sqlite3/sqlite3_$(SQLITE3_VERSION).orig.tar.xz
	$(call EXTRACT_TAR,sqlite3_$(SQLITE3_VERSION).orig.tar.xz,sqlite3-$(SQLITE3_VERSION),sqlite3)
	
	# I change the soversion here to allow installation to /usr/lib on iOS where libsqlite3 is already in the shared cache.
	$(call DO_PATCH,sqlite3,sqlite3,-p1)

ifneq ($(wildcard $(BUILD_WORK)/sqlite3/.build_complete),)
sqlite3:
	@echo "Using previously built sqlite3."
else
sqlite3: sqlite3-setup ncurses readline
	cd $(BUILD_WORK)/sqlite3 && ./configure -C \
		--host=$(GNU_HOST_TRIPLE) \
		--prefix=/usr \
		--enable-readline \
		--disable-editline \
		--enable-session \
		--enable-json1 \
		--enable-fts4 \
		--enable-fts5 \
		--with-readline-inc="-I$(BUILD_BASE)/usr/include/readline" \
		ac_cv_search_tgetent=-lncursesw \
		CPPFLAGS="$(CPPFLAGS) -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_MAX_VARIABLE_NUMBER=250000 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1 -DSQLITE_ENABLE_JSON1=1"
	+$(MAKE) -C $(BUILD_WORK)/sqlite3 all sqldiff
	+$(MAKE) -C $(BUILD_WORK)/sqlite3 install \
		DESTDIR="$(BUILD_STAGE)/sqlite3"
	+$(MAKE) -C $(BUILD_WORK)/sqlite3 install \
		DESTDIR="$(BUILD_BASE)"
	$(CC) $(CFLAGS) -o $(BUILD_STAGE)/sqlite3/usr/bin/lemon $(BUILD_WORK)/sqlite3/tool/lemon.c $(LDFLAGS)
	cp -a $(BUILD_WORK)/sqlite3/.libs/sqldiff $(BUILD_STAGE)/sqlite3/usr/bin
	mkdir -p $(BUILD_STAGE)/sqlite3/usr/share/lemon
	cp -a $(BUILD_WORK)/sqlite3/lempar.c $(BUILD_STAGE)/sqlite3/usr/share/lemon
	touch $(BUILD_WORK)/sqlite3/.build_complete
endif
sqlite3-package: sqlite3-stage
	# sqlite3.mk Package Structure
	rm -rf $(BUILD_DIST)/{sqlite3,lemon} $(BUILD_DIST)/libsqlite3-{1,dev}
	mkdir -p $(BUILD_DIST)/{sqlite3,lemon}/usr/bin \
		$(BUILD_DIST)/libsqlite3-{1,dev}/usr/lib

	# sqlite3.mk Prep sqlite3
	cp -a $(BUILD_STAGE)/sqlite3/usr/bin/{sqlite3,sqldiff} $(BUILD_DIST)/sqlite3/usr/bin

	# sqlite3.mk Prep lemon
	cp -a $(BUILD_STAGE)/sqlite3/usr/share $(BUILD_DIST)/lemon/usr
	cp -a $(BUILD_STAGE)/sqlite3/usr/bin/lemon $(BUILD_DIST)/lemon/usr/bin

	# sqlite3.mk Prep libsqlite3-1
	cp -a $(BUILD_STAGE)/sqlite3/usr/lib/libsqlite3.1.dylib $(BUILD_DIST)/libsqlite3-1/usr/lib

	# sqlite3.mk Prep libsqlite3-dev
	cp -a $(BUILD_STAGE)/sqlite3/usr/include $(BUILD_DIST)/libsqlite3-dev/usr
	cp -a $(BUILD_STAGE)/sqlite3/usr/lib/{pkgconfig,libsqlite3.{a,dylib}} $(BUILD_DIST)/libsqlite3-dev/usr/lib

	# sqlite3.mk Sign
	$(call SIGN,sqlite3,general.xml)
	$(call SIGN,lemon,general.xml)
	$(call SIGN,libsqlite3-1,general.xml)
	
	# sqlite3.mk Make .debs
	$(call PACK,sqlite3,DEB_SQLITE3_V)
	$(call PACK,lemon,DEB_SQLITE3_V)
	$(call PACK,libsqlite3-1,DEB_SQLITE3_V)
	$(call PACK,libsqlite3-dev,DEB_SQLITE3_V)
	
	# sqlite3.mk Build cleanup
	rm -rf $(BUILD_DIST)/{sqlite3,lemon} $(BUILD_DIST)/libsqlite3-{1,dev}

.PHONY: sqlite3 sqlite3-package