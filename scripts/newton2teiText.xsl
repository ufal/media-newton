<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  xmlns:mk="http://ufal.mff.cuni.cz/matyas-kopp"
  exclude-result-prefixes="xs tei mk" >

  <xsl:output method="xml" indent="yes" encoding="UTF-8" />
  <xsl:import href="newton2tei-lib.xsl"/>

  <xsl:template match="/Data/Topics/Topic/Summaries/Summary[10 > position()]/Articles/Article">

    <xsl:variable name="id" select="mk:id(.)"/>
    <xsl:variable name="path" select="mk:path(., $outDir)"/>
    <xsl:message select="concat('INFO: exporting ',$path)"/>
    <xsl:variable name="title" select="mk:title(.)"/>
    <xsl:variable name="article" select="mk:article(.)"/>
    <xsl:result-document href="{$path}" method="xml" indent="yes" encoding="UTF-8" >

<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}" xml:lang="cs">
  <text>
    <front>
      <head type="title" xml:id="{$id}.p1"><xsl:value-of select="$title"/></head>
    </front>
    <body>
      <div type="text">
        <xsl:apply-templates select="$article/Content">
          <xsl:with-param name="id" select="$id"/>
          </xsl:apply-templates>
      </div>
    </body>
  </text>
</TEI>

    </xsl:result-document>
  </xsl:template>

  <xsl:template match="Content">
    <xsl:param name="id"/>
    <xsl:for-each select="tokenize(*/text(), '\n\n\n*')">
      <xsl:if test="normalize-space(.)">
        <p xml:id="{$id}.p{position()+1}">
          <xsl:call-template name="parsePar">
            <xsl:with-param name="text" select="normalize-space(.)"/>
          </xsl:call-template>
        </p>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="parsePar">
    <xsl:param name="text"/>
<!-- TODO parse notes
    (pozn. lokalizační systém na mobilní telefony)
    (hlavní, pozn. red.)
    (pozn.: ještě není vyhodnoceno, zda-li zaznamenali především střelbu nebo referenční hluky)
    (místní obyvatel Zdeněk Kovář zastřelil v restauraci osm lidí a poté sebe – pozn. autora)
    (ve čtvrtek, pozn. aut.)
    (von der Leyenová – pozn. red)
    (čtvrteční, pozn. ČTK)
    (více než je zbytné, pozn. redakce)
    (specialista na poruchy chování a emoční prožívání; poznámka autorky)
    (který jej poprvé definoval, pozn. PP)
-->
    <xsl:value-of select="$text"/>
  </xsl:template>

</xsl:stylesheet>