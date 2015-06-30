build_dir := $(CURDIR)/build
test_dir := $(CURDIR)/test

all: codegen runtime

codegen: FORCE
	cd codegen && cabal build

runtime: FORCE 
	cd runtime && $(MAKE)

test: ctest tastytest

tastytest: FORCE 
	cd codegen && cabal test

ctest: FORCE
	@((test -d $(build_dir)) || (mkdir $(build_dir)))
	@echo "*** Creating cmake build directory: $(build_dir)"
	@(cd $(build_dir); cmake $(cmake_flags) $(test_dir))
	@(cd $(build_dir); ARGS="-D ExperimentalTest --no-compress-output" $(MAKE) test; cp Testing/`head -n 1 Testing/TAG`/Test.xml ./CTestResults.xml)

clean: FORCE
	cd codegen && cabal clean
	cd runtime && $(MAKE) clean
	@(cd test && rm -f *.stg.c 2>/dev/null)
	rm -rf $(build_dir)

FORCE:
