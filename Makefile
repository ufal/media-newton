

DATA := $(shell pwd)/data/
IN := ${DATA}source
DIST := ${DATA}dist
WORK := ${DATA}work

TEIheader := ${WORK}/tei-header
TEItext := ${WORK}/tei-text
TEIANAtext := ${WORK}/tei-ana-text
TEI := ${DIST}/tei
TEIANA := ${DIST}/tei-ana
TEITOK := ${DIST}/teitok
UDPIPE := ${WORK}/udpipe
NAMETAG := ${WORK}/nametag

LOGDIR := $(shell pwd)/logs/

CONFIG := $(shell pwd)/projects/config_cus_1.0.xml
PREFIX := cus_
CORPUS_ID := $(PREFIX)corpus
CORPUS_TEMPLATE := $(WORK)/$(CORPUS_ID).xml

SCHEMA_TEI := tei_all
SCHEMA := $(shell pwd)/schema/$(SCHEMA_TEI).rng

JAVA-MEMORY =
JM := $(shell test -n "$(JAVA-MEMORY)" && echo -n "-Xmx$(JAVA-MEMORY)g")
JAVA-MEMORY-GB = $(shell java $(JM) -XX:+PrintFlagsFinal -version 2>&1| grep " MaxHeapSize"|sed "s/^.*= *//;s/ .*$$//"|awk '{print "\t" $$1/1024/1024/1024}')
SAXON := java $(JM) -jar scripts/bin/saxon.jar

DEBUG := 
XSLDEBUG := $(shell test -n "$(DEBUG)" && echo -n "limit=2")


DISTRO-TASKS := tei tei-ana teitok
SLURM-TASKS := $(addprefix dist-, $(DISTRO-TASKS))

SLURM_PARTITION ?= cpu-troja,cpu-ms
SLURM_CPUS ?= 30
SLURM_MEM ?= 240


-include Makefile.dev

# convert component files to TEI/text
convert2teiText: $(TEItext)
	find $(IN) -type f -name "*.xml" | xargs -I {} $(SAXON) outDir=$< prefix=$(PREFIX) $(XSLDEBUG) -xsl:scripts/newton2teiText.xsl {}

# convert component files to TEI/teiHeader
convert2teiHeader: $(TEIheader)
	find $(IN) -type f -name "*.xml" | xargs -I {} $(SAXON) outDir=$< prefix=$(PREFIX) $(XSLDEBUG) -xsl:scripts/newton2teiHeader.xsl {}

teiText2teiTextAnaUD: $(UDPIPE)
	find $(TEItext) -type f -printf "%P\n" |sort > $(UDPIPE).fl
	perl -I scripts/resources/lib scripts/resources/udpipe2/udpipe2.pl --colon2underscore \
	                               $(TOKEN) \
	                               --model "cs:czech-pdt-ud-2.15-241121" \
	                               --elements "p,head" \
	                               --debug \
																 --use-xpos \
	                               --no-space-in-punct \
	                               --try2continue-on-error \
	                               --filelist $(UDPIPE).fl \
	                               --input-dir $(TEItext) \
	                               --output-dir $(UDPIPE)

teiText2teiTextAnaNER: $(NAMETAG)
	find $(UDPIPE) -type f -printf "%P\n" |sort > $(NAMETAG).fl
	perl -I scripts/resources/lib scripts/resources/nametag2/nametag2.pl \
	                                 $(TOKEN) \
																	 --debug \
	                                 --model "cs:nametag3-czech-cnec2.0-240830" \
																	 --cnec2conll2003 \
	                                 --filelist $(NAMETAG).fl \
	                                 --input-dir $(UDPIPE) \
	                                 --output-dir $(NAMETAG)

corpus-template:
	echo '<?xml version="1.0" encoding="UTF-8"?>' > $(CORPUS_TEMPLATE)
	echo '<teiCorpus xmlns="http://www.tei-c.org/ns/1.0"' >> $(CORPUS_TEMPLATE)
	echo '     xml:id="$(CORPUS_ID)"' >> $(CORPUS_TEMPLATE)
	echo '     xml:lang="cs">' >> $(CORPUS_TEMPLATE)
	echo '   <teiHeader/>' >> $(CORPUS_TEMPLATE)
	find $(TEIheader) -type f -name "*.xml" -printf "%P\n"| xargs -I {} echo '   <xi:include xmlns:xi="http://www.w3.org/2001/XInclude" href="'{}'"/>' >> $(CORPUS_TEMPLATE)
	echo '</teiCorpus>' >> $(CORPUS_TEMPLATE)

dist-tei: $(TEI)
	$(SAXON) -xsl:scripts/distro.xsl \
	    outDir=$< \
			inComponentDir=$(TEItext) \
			inHeaderDir=$(TEIheader) \
			anaDir=$(TEIANA) \
	    inTaxonomiesDir=$(TAXONOMIES) \
	    type=TEI \
			projectConfig=$(CONFIG) \
	    $(CORPUS_TEMPLATE)

dist-tei-ana: $(TEIANA)
	$(SAXON) -xsl:scripts/distro.xsl \
	    outDir=$< \
			inComponentDir=$(NAMETAG) \
			inHeaderDir=$(TEIheader) \
	    inTaxonomiesDir=$(TAXONOMIES) \
	    type=TEI.ana \
			projectConfig=$(CONFIG) \
	    $(CORPUS_TEMPLATE)

dist-teitok: $(TEITOK)
	find $(TEIANA) -type f -printf "%P\n" |grep -v '$(CORPUS_ID)\.'| sed -E "s/(\.ana)?\.xml$$//" |sort > ${WORK}/dist-tei-ana.fl
	cat ${WORK}/dist-tei-ana.fl \
	  | xargs -I {} perl scripts/tei2teitok.pl \
		                            --in $(TEIANA)/{}.ana.xml \
		                            --out $(TEITOK)/{}.tt.xml

$(addprefix slurm-,  $(SLURM-TASKS)): slurm-%: $(LOGDIR)
	@echo "Submitting $* to slurm..."
	@awk 'BEGIN { if ($(JAVA-MEMORY-GB) <= $(SLURM_MEM)) print "WARNING: $(JAVA-MEMORY-GB)G(Jave memory) <  $(SLURM_MEM)G (machine memory)"; else print "Memory test: passed"; }'
	@JOBID=$$( sbatch \
		--parsable \
		--job-name=$* \
		--ntasks=1 \
		--partition=$(SLURM_PARTITION) \
		--cpus-per-task=$(SLURM_CPUS) \
		--mem=$(SLURM_MEM)G \
		--output=$(LOGDIR)/%x.%j.out \
		--wrap="cd $(CURDIR) && $(MAKE) $*" ); \
	echo "Submitted job $$JOBID for $*"

$(TEI) $(TEIANA) $(TEITOK) $(TEItext) $(TEIheader) $(TEIANAtext) $(UDPIPE) $(NAMETAG) $(LOGDIR):
	mkdir -p $@


validate-tei: $(SCHEMA)
	find $(TEI) -type f | xargs -I {} java $(JM) -jar ./scripts/bin/jing.jar $< {}

validate-tei-ana: $(SCHEMA)
	find $(TEIANA) -type f | xargs -I {} java $(JM) -jar ./scripts/bin/jing.jar $< {}

$(SCHEMA):
	mkdir `dirname $@` || :
	wget https://tei-c.org/release/xml/tei/custom/schema/relaxng/$(SCHEMA_TEI).rng -O $@


##################
prereq: parczech



parczech: scripts/resources
	git clone https://github.com/ufal/ParCzech.git --no-checkout $</ParCzech --depth 10 -b master ;\
	cd $</ParCzech ;\
	git sparse-checkout init --cone  ;\
	git sparse-checkout set src/udpipe2 src/nametag2 src/lib || echo "directory exists"
	ln -s ParCzech/src/lib $</lib || : 
	ln -s ParCzech/src/udpipe2 $</udpipe2 || :
	ln -s ParCzech/src/nametag2 $</nametag2 || :
	### 
	cd $</ParCzech ;\
  git checkout ;\
  git pull

scripts/resources:
	mkdir $@

