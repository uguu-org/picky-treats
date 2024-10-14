# Build images and other supporting data.  Takes ~2 minute to build and
# costs ~5M of disk space.
#
# Requires gcc, perl, netpbm, ImageMagick, and Inkscape.
# gcc also needs libpng, and perl needs libxml.
#
# See svg_to_png.sh for more details on Inkscape.

targets = \
	sprites-table-128-128.png \
	card.png \
	data.lua

# Common compiler flags for C/C++ tools.
#
# "-march=native -O3" produces the fastest executables, although these flags
# are here mostly for readability.  For any particular executable, most of
# the time will be spent inside the pre-compiled libpng, and the overall
# build time will be dominated by Inkscape.
cflags = -march=native -O3 -Wall -Wextra -pedantic


# ......................................................................
# {{{ Primary build artefacts.

all: $(targets)

sprites-table-128-128.png: t_sprites.png optimize_png.pl
	perl optimize_png.pl $< > $@

card.png: t_title.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 "(" $< ")" -geometry +22+58 -composite png:- | perl optimize_png.pl > $@

data.lua: generate_collision_table.pl
	perl $< > $@

# }}}

# ......................................................................
# {{{ Launcher images.

t_title.png: t_gray_title.png fs_dither.exe
	./fs_dither.exe $< $@

t_gray_title.png: t_sprites.svg svg_to_png.sh
	./svg_to_png.sh $< $@ 401 2048 767 2095 80

# }}}

# ......................................................................
# {{{ Intermediate files.

# These are written to the current directory like everything else, but
# they mostly follow the naming convention of having a "t_" prefix, so
# it's easy to tell which files are transient.

# All object sprites.

t_sprites.png: t_gray_sprites.png fs_dither.exe
	./fs_dither.exe $< $@

t_gray_sprites.png: t_sprites.svg svg_to_png.sh
	./svg_to_png.sh $< $@

t_sprites.svg: sprites.svg select_layers.pl remove_unused_defs.pl
	perl select_layers.pl 'treats|hand|title' t_gray_sprites.png $< | perl remove_unused_defs.pl > $@

# }}}

# ......................................................................
# {{{ Tools.

dither.exe: dither.c
	gcc $(cflags) $< -lpng -o $@

fs_dither.exe: fs_dither.c
	gcc $(cflags) $< -lpng -o $@

random_dither.exe: random_dither.c
	gcc $(cflags) $< -lpng -o $@

crop_table.exe: crop_table.c
	gcc $(cflags) $< -lpng -o $@

# }}}

# ......................................................................
# {{{ Tests and maintenance commands.

test: \
	test_passed.check_ref \
	test_passed.cleanup_styles \
	test_passed.crop_table \
	test_passed.dither \
	test_passed.element_count \
	test_passed.generate_build_graph \
	test_passed.inline_constants \
	test_passed.no_text_in_sprites \
	test_passed.select_layers \
	test_passed.strip_lua

test_passed.dither: dither.exe test_dither.sh
	./test_dither.sh $< && touch $@

test_passed.remove_unused_defs: remove_unused_defs.pl test_remove_unused_defs.sh
	./test_remove_unused_defs.sh $< && touch $@

test_passed.select_layers: select_layers.pl test_select_layers.sh
	./test_select_layers.sh $< && touch $@

test_passed.generate_build_graph: generate_build_graph.pl test_generate_build_graph.sh
	./test_generate_build_graph.sh $< && touch $@

test_passed.strip_lua: strip_lua.pl test_strip_lua.sh
	./test_strip_lua.sh $< && touch $@

test_passed.check_ref: check_ref.pl test_check_ref.sh
	./test_check_ref.sh $< && touch $@

test_passed.inline_constants: inline_constants.pl test_inline_constants.sh
	./test_inline_constants.sh $< && touch $@

test_passed.element_count: element_count.pl test_element_count.sh
	./test_element_count.sh $< && touch $@

test_passed.cleanup_styles: cleanup_styles.pl test_cleanup_styles.sh
	./test_cleanup_styles.sh $< && touch $@

test_passed.no_text_in_sprites: sprites.svg select_layers.pl element_count.pl
	! ( perl select_layers.pl 'treats|hand|title' t_text_test.png $< | perl element_count.pl - | grep '^text' ) && touch $@

test_passed.crop_table: crop_table.exe test_crop_table.sh
	./test_crop_table.sh $< && touch $@

clean:
	-rm -f $(targets) *.exe *.o test_passed.* t_*

# }}}
