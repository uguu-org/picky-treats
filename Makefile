# Toplevel Makefile for Picky Treats project.
#
# For debug builds:
#
#   make
#
# For release builds:
#
#   make release
#
# Only `pdc` from Playdate SDK is needed for these, plus a few standard
# command line tools.
#
# To refresh game data and build, do one of the following:
#
#   make -j refresh_data && make
#   make -j refresh_data && make release
#
# Refreshing game data requires a few more tools and libraries, see
# data/Makefile for more information.  At a minimum, you will likely need
# to edit data/svg_to_png.sh to set the correct path to Inkscape.

package_name=picky_treats
data_dir=data
source_dir=source
release_source_dir=release_source

# Debug build.
$(package_name).pdx/pdxinfo: \
	$(source_dir)/main.lua \
	$(source_dir)/data.lua \
	$(source_dir)/pdxinfo
	pdc $(source_dir) $(package_name).pdx

# Release build.
release: $(package_name).zip

$(package_name).zip:
	-rm -rf $(package_name).pdx $(release_source_dir) $@
	cp -R $(source_dir) $(release_source_dir)
	perl $(data_dir)/inline_data.pl $(source_dir)/data.lua $(source_dir)/main.lua | perl $(data_dir)/inline_constants.pl | perl $(data_dir)/strip_lua.pl > $(release_source_dir)/main.lua
	pdc -s $(release_source_dir) $(package_name).pdx
	zip -9 -r $@ $(package_name).pdx

# Refresh data files in source directory.
refresh_data:
	$(MAKE) -C $(data_dir)
	cp -f $(data_dir)/sprites-table-128-128.png $(source_dir)/images/
	cp -f $(data_dir)/card.png $(source_dir)/launcher/
	cp -f $(data_dir)/data.lua $(source_dir)/

clean:
	$(MAKE) -C $(data_dir) clean
	-rm -rf $(package_name).pdx $(package_name).zip $(release_source_dir)
