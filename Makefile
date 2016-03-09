I_D = draft-ietf-netmod-routing-cfg
REVNO = 21
DATE ?= $(shell date +%F)
MODULES = ietf-routing ietf-ipv4-unicast-routing ietf-ipv6-unicast-routing # example-rip
SUBMODULES = ietf-ipv6-router-advertisements
FIGURES = config-coll-tree.txt state-coll-tree.txt \
	config-tree.txt state-tree.txt example-rip.yang example-net.txt
EXAMPLE_BASE = example
EXAMPLE_TYPE = get-reply
baty = $(EXAMPLE_BASE)-$(EXAMPLE_TYPE)
EXAMPLE_INST = $(baty).xml
PYANG_OPTS =

# Paths for pyang
export PYANG_RNG_LIBDIR ?= /usr/share/yang/schema
export PYANG_XSLT_DIR ?= /usr/share/yang/xslt
export YANG_MODPATH ?= .:/usr/share/yang/modules/ietf:/usr/share/yang/modules/iana

artworks = $(addsuffix .aw, $(yams) $(yass)) $(EXAMPLE_INST).aw \
	   $(addsuffix .aw, $(FIGURES))
idrev = $(I_D)-$(REVNO)
yams = $(addsuffix .yang, $(MODULES))
yass = $(addsuffix .yang, $(SUBMODULES))
xsldir = .tools/xslt
xslpars = --stringparam date $(DATE) --stringparam i-d-name $(I_D) \
	  --stringparam i-d-rev $(REVNO)
schemas = $(baty).rng $(baty).sch $(baty).dsrl
y2dopts = -t $(EXAMPLE_TYPE) -b $(EXAMPLE_BASE)

.PHONY: all clean rnc refs validate yang

all: $(idrev).txt $(schemas) model.tree

refs: stdrefs.ent

yang: $(yams) $(yass)

$(idrev).xml: $(I_D).xml $(artworks) figures.ent yang.ent
	@xsltproc --novalid $(xslpars) $(xsldir)/upd-i-d.xsl $< | \
	  xmllint --noent -o $@ -

$(idrev).txt: $(idrev).xml
	@xml2rfc --dtd=.tools/schema/rfc2629.dtd $<

hello.xml: $(yams) $(yass) hello-external.ent
	@echo '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">' > $@
	@echo '<capabilities>' >> $@
	@echo '<capability>urn:ietf:params:netconf:base:1.1</capability>' >> $@
	@for m in $(yams); do \
	  capa=$$(pyang $(PYANG_OPTS) -f capability --capability-entity $$m); \
	  if [ "$$capa" != "" ]; then \
	    echo "<capability>$$capa</capability>" >> $@; \
	  fi \
	done
	@cat hello-external.ent >> $@
	@echo '</capabilities>' >> $@
	@echo '</hello>' >> $@

stdrefs.ent: $(I_D).xml
	xsltproc --novalid --output $@ $(xsldir)/get-refs.xsl $<

yang.ent: $(yams) $(yass)
	@echo '<!-- External entities for files with modules -->' > $@
	@for f in $^; do                                                 \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;          \
	done
ifneq ($EXAMPLE_INST,)
	@echo '<!ENTITY '"$(EXAMPLE_INST) SYSTEM \"$(EXAMPLE_INST).aw\">" >> $@
endif

figures.ent: $(FIGURES)
ifeq ($(FIGURES),)
	@touch $@
else
	@echo '<!-- External entities for files with figures -->' > $@; \
	for f in $^; do                                            \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;  \
	done
endif

%.yang: %.yinx
	@xsltproc --xinclude $(xsldir)/canonicalize.xsl $< | \
	  xsltproc --output $@ $(xslpars) $(xsldir)/yin2yang.xsl -

ietf-%.yang.aw: ietf-%.yang
	@pyang $(PYANG_OPTS) --ietf $<
	@echo '<artwork>' > $@
	@echo '<![CDATA[<CODE BEGINS> file '"\"ietf-$*@$(DATE).yang\"" >> $@
	@echo >> $@
	@cat $< >> $@
	@echo >> $@
	@echo '<CODE ENDS>]]></artwork>' >> $@

%.aw: %
	@echo '<artwork><![CDATA[' > $@; \
	cat $< >> $@;                    \
	echo ']]></artwork>' >> $@

$(schemas): hello.xml
	yang2dsdl $(y2dopts) -L $<

%.rnc: %.rng
	trang -I rng -O rnc $< $@

rnc: $(baty).rnc

validate: $(EXAMPLE_INST) $(schemas)
	@yang2dsdl -j -s $(y2dopts) -v $<

model.tree: hello.xml
	pyang $(PYANG_OPTS) -f tree -o $@ -L $<

state-tree.txt: model.tree
	@awk -v yam=ietf-routing -v root=routing-state -v types=1 \
	     -f .tools/awk/tree.awk $< > $@

config-tree.txt: model.tree
	@awk -v yam=ietf-routing -v root=routing -v types=1 \
	     -f .tools/awk/tree.awk $< > $@

state-coll-tree.txt: model.tree
	@awk -v yam=ietf-routing -v root=routing-state -v depth=4 \
	     -f .tools/awk/tree.awk $< > $@

config-coll-tree.txt: model.tree
	@awk -v yam=ietf-routing -v root=routing -v depth=4 \
	     -f .tools/awk/tree.awk $< > $@

static-routes-tree.txt: model.tree
	@awk -v yam=ietf-routing \
	     -v root=routing/routing-instance*/routing-protocols/routing-protocol*/static-routes \
	     -f .tools/awk/tree.awk $< > $@
clean:
	@rm -rf *.rng *.rnc *.sch *.dsrl hello.xml model.tree $(yass) \
	        $(yams) $(idrev).* $(artworks) figures.ent yang.ent
