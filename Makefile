builddir=build
srcdir=.

ifdef RELEASE
BUILD_TYPE=RELEASE
else
BUILD_TYPE=DEBUG
endif
LAST_BUILD_TYPE := $(shell cat build/.build_type 2>/dev/null)
ifneq ($(BUILD_TYPE),$(LAST_BUILD_TYPE))
NEED_CLEAN=clean
endif

ifeq ($(BUILD_TYPE),RELEASE)

ifneq ($(shell which yuicompressor),)
YUICOMPRESSOR = yuicompressor
else ifneq ($(wildcard yuicompressor.jar),)
YUICOMPRESSOR = java -jar yuicompressor.jar
endif
ifneq ($(shell which closure),)
CLOSURECOMPILER = closure
else ifneq ($(wildcard compiler.jar),)
CLOSURECOMPILER = java -jar compiler.jar
endif
ifneq ($(shell which htmlcompressor),)
HTMLCOMPRESSOR = htmlcompressor
else ifneq ($(wildcard htmlcompressor.jar),)
CLOSURECOMPILER = java -jar htmlcompressor.jar
endif

ifdef YUICOMPRESSOR
COMPRESS_CSS  = $(YUICOMPRESSOR) --type css
endif

ifdef CLOSURECOMPILER
COMPRESS_JS   = $(CLOSURECOMPILER) --compilation_level SIMPLE_OPTIMIZATIONS
else ifdef YUICOMPRESSOR
COMPRESS_JS   = $(YUICOMPRESSOR) --type js
endif

ifdef HTMLCOMPRESSOR
COMPRESS_HTML = $(HTMLCOMPRESSOR) --type html
endif

ifdef COMPRESS_CSS
POSTPROCESS_CSS  := | $(COMPRESS_CSS)
endif
ifdef COMPRESS_JS
POSTPROCESS_JS   := | $(COMPRESS_JS)
endif
ifdef COMPRESS_HTML
POSTPROCESS_HTML := | $(COMPRESS_HTML)
endif

POSTPROCESS_CSS  += | $(MAKE) _add_license
POSTPROCESS_JS   += | $(MAKE) _add_license
POSTPROCESS_HTML += | $(MAKE) _add_license HTML=1
endif

PREPROCESS = perl $(srcdir)/preprocess.pl

comma := ,
empty :=
space := $(empty) $(empty)

JSFILES         := $(wildcard $(srcdir)/code/*.js)
CSSFILES        := $(wildcard $(srcdir)/code/*.css)
HTMLFILES       := $(wildcard $(srcdir)/html/*.html)
SRCFILES        =  $(JSFILES) $(CSSFILES) $(HTMLFILES)
BASEJSFILES     =  $(subst $(srcdir)/code/,,$(JSFILES))
BASECSSFILES    =  $(subst $(srcdir)/code/,,$(CSSFILES))
BASEHTMLFILES   =  $(subst $(srcdir)/html/,,$(HTMLFILES))
BASEFILES       =  $(BASEJSFILES) $(BASECSSFILES) $(BASEHTMLFILES)
BUILDJSFILES    =  $(addprefix $(builddir)/code/, $(BASEJSFILES))
BUILDCSSFILES   =  $(addprefix $(builddir)/code/, $(BASECSSFILES))
BUILDHTMLFILES  =  $(addprefix $(builddir)/html/, $(BASEHTMLFILES))
BUILDFILES      =  $(BUILDJSFILES) $(BUILDCSSFILES) $(BUILDHTMLFILES)
BUILDFILES += $(builddir)/code/building-rollup.js


.PHONY: build
build: $(NEED_CLEAN) $(BUILDFILES)
	@echo $(BUILD_TYPE) > $(builddir)/.build_type

.PHONY: _add_license
_add_license :
ifdef HTML
	@cat -
	@echo "<!--"
else
	@echo "/*"
endif
	@echo "Copyright (c) $(shell date +%Y), Lacuna Expanse Corp. All rights reserved."
	@echo "Code licensed under the BSD License:"
	@echo "http://github.com/plainblack/Lacuna-Web-Client/blob/$(shell git rev-parse --short HEAD)/LICENSE"
	@echo "Built from: http://github.com/plainblack/Lacuna-Web-Client/commit/$(shell git rev-parse --short HEAD)"
ifdef HTML
	@echo "-->"
else
	@echo "*/"
	@cat -
endif

$(builddir)/%.css : PPTYPE=CSS
$(builddir)/%.js : PPTYPE=JS
$(builddir)/%.html : PPTYPE=HTML

$(builddir)/% : $(srcdir)/%
	@mkdir -p $(dir $@)
	$(PREPROCESS) $^ $(POSTPROCESS_$(PPTYPE)) > $@

$(builddir)/code/building-rollup.js : $(srcdir)/code/building*.js
	@mkdir -p $(dir $@)
	$(PREPROCESS) $^ $(POSTPROCESS_JS) > $@

.PHONY: check
check: build
	jsl -nologo -conf .jslint -nofilelisting $(foreach file,$(BUILDJSFILES),-process $(file))

.PHONY: clean
clean:
	rm -rf build

