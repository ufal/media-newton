

DATA := $(shell pwd)/data/
IN := ${DATA}source
DIST := ${DATA}dist
WORK := ${DATA}work

PERLBREW_ROOT=~/perl5/perlbrew
PERL := $(shell test -n "$(USE_PERL)" && echo -n "$(PERLBREW_ROOT)/perls/$(USE_PERL)/bin/perl" || echo -n "perl")
SLURM_PERL := $(shell test -n "$(USE_PERL)" && echo -n "USE_PERL=$(USE_PERL)")


INpatched := ${WORK}/source-patched
TEIheader := ${WORK}/tei-header
TEItext := ${WORK}/tei-text
TEIANAtext := ${WORK}/tei-ana-text
TEI := ${DIST}/tei
TEIANA := ${DIST}/tei-ana
TEITOK := ${DIST}/teitok
TEITOK-TOK := ${TEITOK}/xmlfiles
TEITOK-STANDOFF := ${TEITOK}/Annotations
TEITOK-TMP := ${TEITOK}/tmp
TEITOK-CQP := ${TEITOK}/cqp
UDPIPE := ${WORK}/udpipe
NAMETAG := ${WORK}/nametag
cNAMETAG := ${WORK}/nametag-conllu
cSOUDEC :=  ${WORK}/soudec-conllu
SOUDEC :=  ${WORK}/soudec

LOGDIR := $(shell pwd)/logs/

CONFIG := $(shell pwd)/projects/config_cus_1.0.xml
CQPsettings := $(shell pwd)/projects/cqp_cus_1.0.xml
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


DISTRO-TASKS := tei tei-ana teitok teitok2cqp
SLURM-TASKS := $(addprefix dist-, $(DISTRO-TASKS)) teiTextAnaNER2teiSOUDEC DEV

SLURM_PARTITION ?= cpu-troja,cpu-ms
SLURM_CPUS ?= 30
SLURM_MEM ?= 240

THREADS ?= 1

-include Makefile.dev

patchSource: $(INpatched)
	find $(IN) -type f -name "*.xml" | parallel -P$(THREADS) "cat {} | perl -C -pe 's/\x{00AD}//g' > $(INpatched)/{/}"

# convert component files to TEI/text
convert2teiText: $(TEItext)
	find $(INpatched) -type f -name "*.xml" | xargs -I {} $(SAXON) outDir=$< prefix=$(PREFIX) $(XSLDEBUG) -xsl:scripts/newton2teiText.xsl {}

# convert component files to TEI/teiHeader
convert2teiHeader: $(TEIheader)
	find $(INpatched) -type f -name "*.xml" | xargs -I {} $(SAXON) outDir=$< prefix=$(PREFIX) $(XSLDEBUG) -xsl:scripts/newton2teiHeader.xsl {}

teiText2teiTextAnaUD: $(UDPIPE)
	find $(TEItext) -type f -printf "%P\n" |sort > $(UDPIPE).fl
	$(PERL) -I scripts/resources/lib scripts/resources/udpipe2/udpipe2.pl --colon2underscore \
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
	$(PERL) -I scripts/resources/lib scripts/resources/nametag2/nametag2.pl \
	                                 $(TOKEN) \
																	 --debug \
	                                 --model "cs:nametag3-czech-cnec2.0-240830" \
																	 --cnec2conll2003 \
	                                 --filelist $(NAMETAG).fl \
	                                 --input-dir $(UDPIPE) \
	                                 --output-dir $(NAMETAG)


teiTextAnaNER2teiSOUDEC: _teiTextAnaNER2conlluNER _conlluNER2conlluSOUDEC _conlluSOUDEC2teiSOUDEC

_teiTextAnaNER2conlluNER: $(cNAMETAG)
	find $(NAMETAG) -type f -printf "%P\n" |sort > $<.fl
	cat $<.fl | sed 's@[^/]*$$@@'|sort|uniq|xargs -I {} mkdir -p $(cNAMETAG)/{}
	cat $<.fl |sed 's/.xml$$//'| parallel -P$(THREADS) '$(SAXON) outDir=$< -xsl:scripts/tei2conllu.xsl $(NAMETAG)/{}.xml | $(PERL) ./scripts/addTokenRange2conllu.pl > $(cNAMETAG)/{}.conllu'


_conlluNER2conlluSOUDEC: $(cSOUDEC)
	find $(cNAMETAG) -type f -printf "%P\n" |sort > $<.fl
	cat $<.fl | sed 's@[^/]*$$@@'|sort|uniq|xargs -I {} mkdir -p $(cSOUDEC)/{}
	cat $<.fl | parallel -P$(THREADS) '$(PERL) ./scripts/resources/soudec/system/soudec.pl --input-file $(cNAMETAG)/{} --input-format conllu --output-format conllu > $(cSOUDEC)/{}'

_conlluSOUDEC2teiSOUDEC: $(SOUDEC)
	find $(cSOUDEC) -type f -printf "%P\n" |sort > $<.fl
	cat $<.fl | sed 's@[^/]*$$@@'|sort|uniq|xargs -I {} mkdir -p $(SOUDEC)/{}
	cat $<.fl | parallel -P$(THREADS) '$(PERL) ./scripts/conlluSoudec2teiStandOffSoudec.pl {/.} < $(cSOUDEC)/{} > $(SOUDEC)/{.}.xml'

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
			inSouDeCDir=$(SOUDEC) \
			inHeaderDir=$(TEIheader) \
	    inTaxonomiesDir=$(TAXONOMIES) \
	    type=TEI.ana \
			projectConfig=$(CONFIG) \
	    $(CORPUS_TEMPLATE)

dist-teitok: $(TEITOK-TOK) $(TEITOK-STANDOFF)
	find $(TEIANA) -type f -printf "%P\n" |grep -v '$(CORPUS_ID)\.'| sed -E "s/(\.ana)?\.xml$$//" |sort > ${WORK}/dist-tei-ana.fl
	cat ${WORK}/dist-tei-ana.fl \
	  | parallel -P$(THREADS) '$(PERL) scripts/tei2teitok.pl --in $(TEIANA)/{}.ana.xml --out $(TEITOK-TOK)/{}.tt.xml --outdir-standoff $(TEITOK-STANDOFF)'

dist-teitok2cqp: $(TEITOK-TMP) $(TEITOK-CQP) check-prereq-teitok2cqp
	settings=`realpath $(CQPsettings)`;\
	teitok2cqp=`realpath scripts/teitok2cqp.pl`;\
	cd $(TEITOK); \
	perl $$teitok2cqp --setfile=$$settings



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
		--wrap="cd $(CURDIR) && $(MAKE) $* THREADS=$(SLURM_CPUS) $(SLURM_PERL)" ); \
	echo "Submitted job $$JOBID for $*"

$(INpatched) $(TEI) $(TEIANA) $(TEITOK-TOK) $(TEITOK-STANDOFF) $(TEITOK-TMP) $(TEITOK-CQP) $(TEItext) $(TEIheader) $(TEIANAtext) $(UDPIPE) $(NAMETAG) $(cNAMETAG) $(cSOUDEC) $(SOUDEC) $(LOGDIR):
	mkdir -p $@


validate-tei: $(SCHEMA)
	find $(TEI) -type f | xargs -I {} java $(JM) -jar ./scripts/bin/jing.jar $< {}

validate-tei-ana: $(SCHEMA)
	find $(TEIANA) -type f | xargs -I {} java $(JM) -jar ./scripts/bin/jing.jar $< {}

$(SCHEMA):
	mkdir `dirname $@` || :
	wget https://tei-c.org/release/xml/tei/custom/schema/relaxng/$(SCHEMA_TEI).rng -O $@


##################
prereq: parczech soudec

soudec: scripts/resources
	git clone https://github.com/matyaskopp/soudec.git $</soudec ;\
	cd $</soudec ;\
	git checkout conllu-input

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

check-prereq-teitok2cqp:
	@test -f $(CQPsettings) || (echo "missing cqp setting file CQPsettings=$(CQPsettings)" && exit 1)
	@test -f scripts/bin/tt-cwb-encode || (echo "missing scripts/bin/tt-cwb-encode" && exit 1)
	@test -f scripts/bin/cwb-makeall || (echo "missing scripts/bin/cwb-makeall" && exit 1)
