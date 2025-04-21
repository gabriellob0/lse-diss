#align(center, text(18pt)[
  *Title*
])

#set page(numbering: "1", margin: 1.5in)

#set heading(numbering: "1.")
//#show heading: set block(above: 1.8em, below: 1em)

#set text(font: "libertinus serif", size: 12pt, top-edge: 0.8em, bottom-edge: -0.2em)
#set par(leading: 1em, spacing: 1em, justify: true, first-line-indent: 2em)

#show figure: set figure.caption(position: top)
#show figure.caption: set text(13pt)
#set figure.caption(separator: [#linebreak()])

#show bibliography: set par(leading: 0em)


= Introduction

Researchers have conceptualised innovation as a key economic force throughout the discipline's history. It is most prominent as a central component of economic growth, where technological change drives sustained increases in living standards. However, measurement and methodological barriers hampered research that directly evaluates the empirical aspects of innovation. While some innovation inputs, such as R&D spending, are directly observed, knowledge is not easily quantified, and the complexity of the networks governing its creation and dissemination poses a significant identification challenge.

The literature has attempted to overcome these empirical challenges in two primary ways: with measures of investment in innovation and through patent data. The second, which I focus on here, comprises a complete census of all patenting activity under a patent office and contains extensive information about inventions, inventors, and intellectual property rights holders. Although patents are only intermediate products in the innovation process, they offer a direct insight into how knowledge spreads since each patent cites prior art to demonstrate how it stands above it. #footnote[For example, see the Patent and Trademark Law Amendments Act #cite(<RN25>, form: "prose"), which codifies conditions for the citation of prior art in the US.]

One focal point for research using citation data has been testing whether knowledge spillovers are geographically localised. In the case of patent citations, this is akin to asking if inventors who cite each other also tend to be near each other once we control for other drivers of spatial concentration. To test this hypothesis, I use data from the United States Patent and Trademark Office (USPTO) on patents and citations. My primary contribution is to adopt tools from natural language processing to improve matching approaches developed in prior research.

After reviewing relevant literature on the localisation of knowledge spillovers, I discuss my conceptual framework in #link(<section2>)[Section 2], data and methods in #link(<section3>)[Section 3], and results in #link(<section4>)[Section 4]. Finally, I conclude with a summary and potential extension in #link(<section5>)[Section 5].

== Patent citations and knowledge spillovers

#cite(<RN1>, form: "prose") introduced many key ideas underlying the analysis of knowledge spillovers through patent data. They argue that patent citations can accurately reflect these spillovers once we exclude commercial relations between inventors and assignees. The key argument is that inventors do not include citations that do not reflect spillovers since it would unnecessarily restrict the scope of an invention. Conversely, not citing a patent reflecting a knowledge flow would be challenged by the patent examiner, an expert over the relevant technologies.

However, findings could still reflect other agglomerative forces even if we exclude commercial transactions. Firms and inventors can benefit from sharing inputs to production and improve matching in labour markets when they co-locate @RN23[Section 6.4]. #cite(<RN1>, form: "prose")\'s insight was to create a control group of patents that mimic the technological and temporal characteristics of the citing patents. For each cited-citing patent pair, they find a control patent that does not cite the cited patent and has the same application year and three-digit United States Patent Classification (USPC) class as the citing patent.

They find localisation at the Standard Metropolitan Statistical Area (SMSA), state, and national levels. However, these results depended on how well the three-digit classes proxied endogenous factors. This issue led #cite(<RN3>, form: "prose") to use the six-digit classes for matching controls to reassess earlier results. They find no evidence of intranational localisation. They argued that three-digit controls hid significant intra-class heterogeneity, but #cite(<RN4>, form: "prose") commented that boundaries between six-digit classes were arbitrary. #cite(<RN7>, form: "prose") wrote another reply, but the issue remained unsettled.

#cite(<RN2>, form: "prose") followed in the spirit of these earlier papers but proposed important methodological advances. Its primary contribution was to adapt the localisation test of #cite(<RN28>, form: "prose") for the context of patent citations. #cite(<RN1>, form: "prose") and #cite(<RN3>, form: "prose") used a discrete localisation measure. They compared the frequency at which cited and citing patents originated in the same discrete spatial unit (i.e., SMSA, state, and country) to that of cited and control. Not only did two patents in neighbouring units have the same impact as those across the country in the final results, also implied that the results were sensitive to the modifiable areal unit problem @RN27.

In contrast, the #cite(<RN28>, form: "prose") test, which I describe in more detail in #link(<section3>)[Section 3], treats observations as points in continuous space. This approach addresses the aforementioned issues and incorporates a richer information set in estimated parameters. #cite(<RN2>, form: "prose") find evidence supporting localisation in 70% of all three-digit classes when using three-digit controls and in a third when using six-digit controls. Additionally, more than 10% of classes showed dispersion when using six-digit controls.

The latter point implies that aggregate results might fail to show localisation as the opposing forces would cancel out, which explains the different results in the original papers. However, it does not address the quality of either control. To do so, #cite(<RN2>, form: "prose") conducted a sensitivity analysis which generalises the controls to include three and six-digit as limiting cases. Their simulations show that most classes will still show localisation unless the matching procedure introduces extremely high selection bias.

== Developments in patent text analysis

Although results from #cite(<RN2>, form: "prose") show that the evidence for localisation is robust, developments in patent analysis tools have created an opportunity to re-examine the matching approach. Natural language processing (NLP) has progressed incredibly in the past few years, and patents contain rich textual data in their abstracts, claims, and invention descriptions. Economists have already begun incorporating textual data sources in research, but only in a limited capacity. For an introduction to text data in economics, see #cite(<RN17>, form: "prose").

#cite(<RN18>, form: "prose") use the Jaccard similarity coefficient, the size of the intersection of words divided by the size of the union of words in two documents, to identify similar patents using their titles and abstracts. They found that patents matched with this method were likelier to have the same assignees and inventors, technological classification, and cite one another. The results were also validated by a panel of experts, highlighting that the index had weak matching power for patents with little text. As an application, they conduct a discrete space version of the matching approach, finding evidence for localisation.

However, #cite(<RN18>, form: "prose") and other uses of textual data within innovation economics @RN16 @RN29[for example] have focused on simple text-based statistics, far behind the current state-of-the-art. Since #cite(<RN31>, form: "prose") introduced the transformer architecture, deep learning has dominated much of the natural language domain. A leading use of the architecture has been for contextual embeddings, which are vector representations of the meaning of documents. These have since outperformed previous approaches in tasks like clustering, similarity, and information retrieval @RN20, and researchers can easily access pre-trained models through libraries like Sentence Transformers in Python.

Once we encode a patent's text as an embedding, we can obtain a similarity measure between patents by calculating the vectors' angle (i.e., the cosine). More similar patents would have a smaller angle between their encodings, and we can explore the similarity space using nearest neighbours algorithms @RN16[Section 6.4]. #cite(<RN9>, form: "prose") evaluate the performance of embedding models for patent similarity and find that transformer-based models outperform static measures. They use patent interferences, the case of distinct inventors submitting nearly identical claims simultaneously, as the benchmark for these tests.

I use a state-of-the-art contextual embedding model to match control to citing patents. However, due to time constraints, I have not fine-tuned the model. Despite this limitation, the model I use performs significantly better on benchmarks than the baseline contextual embedding model used by #cite(<RN9>, form: "prose"). #cite(<RN24>, form: "prose") is the only application of contextual embeddings in a matching localisation estimator that I could find. However, because it uses a discrete measure of space, it also suffers from spatial aggregation problems. They generally find weaker localisation evidence than #cite(<RN1>, form: "prose").

== Alternative approaches and issues <section1.3>

Many authors have used alternative approaches to identify various aspects of agglomeration, including the localisation of knowledge spillovers. #cite(<RN33>, form: "prose") find that R&D labs are highly concentrated. #cite(<RN34>, form: "prose") match patents from these R&D clusters to show that these citations are also highly localised. They find that discrete agglomeration measures are likely to understate the degree of localisation and that knowledge spillovers operate over short distances.

The latter point matches with evidence from #cite(<RN49>, form: "prose"), which uses granular location data of advertising agencies in Manhattan and find that spillovers decay quickly. #cite(<RN11>, form: "prose"), further discussed in #link(<section3>)[Section 3], provide a theoretical model showing that small interaction distances form larger clusters than these distances. They find that patent citation data generally supports their model's predictions. Other research supports localisation in the introduction of new words to trademarks @RN43, patent interferences @RN44, and patent and research citations amongst universities @RN45.

Although inventors generally add patent citations, examiners and third parties might include them. #cite(<RN6>, form: "prose") compared variation within a patent in matching rates between inventor-added and examiner-added citations, finding that inventor-added ones are more localised. However, he uses a discrete space estimator. #cite(<RN34>, form: "prose") re-tested their hypothesis with and without examiner-added citations, finding that the exclusion has no significant impact on the final results. Interestingly, #cite(<RN46>, form: "prose") finds that examiner-added citing patents' texts are more similar to their cited patents than inventor-added.

#cite(<RN46>, form: "prose") also finds that either case is more similar than between non-citing patents, but some have raised concerns about citation data in economics. #cite(<RN47>, form: "prose") compare patent citations with a survey of research reports from firm's R&D lab managers. They find that patents tend not to cite basic research important to their development, pointing towards understanding citations as capturing specific elements of knowledge spillovers. #cite(<RN48>, form: "prose") show that the nature of patent citations has also been changing over time using measures of textual similarity. Hence, economists should consider citations alongside other measures and be careful when comparing across periods.

Researchers have also made significant methodological advances. #cite(<RN34>, form: "prose") use coarsened exact matching @RN35, which improves the balance of groups compared to my approach. This estimator and other balancing methods, such as the Covariate Balancing Propensity Score @RN36, could efficiently incorporate even more information into creating balanced patent analysis samples.

Continuous space estimators have also been more prevalent in economics since #cite(<RN28>, form: "prose"). #cite(<RN40>, form: "prose") have introduced a typology of these measures. Some measures, such as #cite(<RN41>, form: "prose"), might provide more interpretable estimators with better properties, but economists have not generally adopted them.

= Conceptual framework <section2>

= Data and methods <section3>

== Sample construction

I used data from the USPTO's PatentsView platform, which helps disseminate intellectual property data. It contains quarterly updated datasets created from raw patent information. The datasets undergo an entity (e.g., inventors, assignees, and locations) disambiguation process. PatentsView also standardises locations with places from the OSMNames project #footnote[The OSMNames database contains place names from OpenStreetMap and geographic information. It is available at #link("https://osmnames.org/").]. Finally, it contains data on five different patent classification systems, including the USPC and its successor, the Cooperative Patent Classification (CPC).

The platform serves data through an API and bulk downloads files. I used the API to fetch all utility patents granted between 2005 and 2025 with at least one US-based inventor and one US-based corporate assignee. I then excluded all patents with multiple assignees, any missing information, or citations not added by inventors or examiners. Finally, I removed those patents with abstracts in the bottom and top 0.01 per cent of the character count. These conditions were satisfied by around 2 million unique patents and 11,500 unique inventors. I collected citations, locations, and CPC class information from the bulk download files.

I chose utility patents and corporate assignees to match the sample construction choices of #cite(<RN1>, form: "prose") and #cite(<RN3>, form: "prose"). Previous papers generally included patents granted between the mid-70s and 1990 or 2000, so my sample covers a different period. This fact likely would imply weaker localisation effects if we consider the increased importance of the internet. I restricted the number of assignees for two primary reasons: it simplified my coding, and multiple assignees could reflect complex commercial arrangements with inventors.

I chose utility patents and corporate assignees to match the sample construction choices of #cite(<RN1>, form: "prose") and #cite(<RN3>, form: "prose"). Previous papers generally included patents granted between the mid-70s and 1990 or 2000, so my sample covers a different period. This fact likely would imply weaker localisation effects if we consider the increased importance of the internet. For example, #cite(<RN39>, form: "prose") highlight the increase in cross-country inventor teams. I restricted the number of assignees for two primary reasons: it simplified my coding, and multiple assignees could reflect complex commercial arrangements with inventors.

Missing observations are likely missing randomly and amount to less than a thousand observations. I observed that summary tables describing missingness varied between requests for the same data, likely indicating API issues. The applicant, the examiner, and third parties can include citations. I only kept the first two since the third, which comprises a small group, might not reflect spillovers. Although we could use the same argument to favour removing examiner-added citations, previous research has not used this restriction. An interesting extension would have been to examine both samples, but given time restrictions, I opted for the larger one.

Following the results of #cite(<RN18>, form: "prose"), I restricted the abstract size to improve the matching quality. Short abstracts, the shortest being three characters, likely do not contain enough information to generate an appropriate embedding. Long abstracts would either require trimming prior to encoding or a model with a longer sequence length (i.e., the length of the text it can encode). Models that satisfy the latter condition require more compute, but given that the right tail of character sizes is thin, the impact of including them is likely nil.


== Matching strategy

The general matching procedure is as follows. First, we select a period from which we define a set of cited patents. We then find all patents that cite any of the patents in the originating set. The cited-citing pairs then correspond to our treatment group. For each cited-citing pair, we define a set of multiple control patents that do not cite the cited patent of the pair but have characteristics similar to those of the control. The cited-control pairs correspond to the control group.

I intended to define the originating set as patents granted between 2005 and 2010 and consider all citations in my raw data. However, the matching process became too computationally expensive, so I had to create a reduced set to satisfy my time constraints. I defined all patents granted in the first month of 2005 with at least one citation in my data over the next five years as belonging to the cited set. I then joined each citing patent in these five years to their respective citation. As in previous papers, I exclude any cited-citing pairs with the same assignee or any inventor in common. These citations likely reflect commercial arrangements between assignees and inventors or continued work, so they are not true externalities.

To select the control patents, I proceeded in two steps. First, for each cited-citing pair, I select all patents granted between 2005 and 2010 with an application date within 180 days of the citing patent's application date, removing those with the same assignee or inventors as their respective cited patent. Then, I encoded all unique citing and potential control patents as embeddings, and for each citing patent, I found the patents in the 99.9th similarity quantile. The intersection between patents within the date range and the similarity quantile corresponds to the set of admissible controls. #link(<table1>)[Table 1] shows the count of unique patents before and after the embeddings — only a single cited patent had no citing patent with an appropriate control patent.

#figure(image("table1.png"), kind: table) <table1>

To encode the patent abstracts, I used the "nomic-embed-text-v2-moe" embedding model @RN38. This model has open-sourced data, weights (analogous to regression coefficients), and code and is available on HuggingFace. Then, I queried the nearest neighbours, as determined by the cosine of the embeddings, with an approximate nearest neighbour algorithm. The similarity quantile corresponded to the 308 nearest neighbours.

I also matched the final set of cited patents to their respective CPC sections. There are nine sections, A to H and Y, and patents might have more than one section. #link(<table2>)[Table 2] lists the number of patents in each section alongside their description. Although the number of cited patents is proportional to the number of cite-citing-control triples, it is imperfect. This fact might indicate class heterogeneity in citations and matching rates. Coupled with the points I make in #link(<section1.3>)[Section 1.3], we must be careful when interpreting differences in localisation across classes.

#figure(image("table2.png"), kind: table) <table2>

#link(<figure1>)[Figure 1] shows a random sample of embeddings represented in 2 dimensions using the t-SNE dimensionality reduction algorithm from the original 256 dimensions. Hence, proximity denotes semantic similarity. Colours denote the patent class, and we see evidence of clustering based on these colours. These patterns highlight how the text and the classes of the patents are connected, which is captured by the embeddings.

#figure(
  [
    #image("figure1.png")
    #block(width: 95%)[
      #set text(10pt)
      #set align(left)
      #set par(leading: 0em, justify: false)
      Notes: The figure shows a two-dimensional visualisation of 50,000 citing and control patent embeddings from a random sample. I keep only a unique CPC section selected at random per patent. I reduce dimensions using the t-SNE algorithm with a perplexity of 30 and theta of 0.5. Closer observations have similar meanings.]
  ],
  caption: [
    #set text(size: 10pt)
    Patent embeddings and CPC classes
  ]
) <figure1>

== Localisation test

I calculated the geodesic distance between all cited-citing and cited-control pairs using their latitudes and longitudes for the localisation test. However, patents do not have a location, so most previous research constructed one from inventor locations. Since patents have multiple inventors who may work in different parts of the country, I followed #cite(<RN11>, form: "prose")\'s procedure to construct them.

First, I selected areas where the most inventors live for each patent. If this location was not unique, I selected the one corresponding to the lowest inventor sequence within the restricted set. The inventor sequence variable lists the order in which the patent lists its inventors. Generally, the first inventor has contributed the most to the invention, and the order between the others matters less. Therefore, the second step should capture the location that contributed the most or at least be random.

#link(<figure2>)[Figure 2] shows the matched sample's binned log count of all cited, citing, and control patents. As expected, the unconditional spatial distribution of patents shows geographic concentration. A clear example is Silicon Valley in California. This factor is one of the primary motivators for a matching strategy.

#figure(
  [
    #box(image("figure2.png"), clip: true, inset: (top: -0.6cm, bottom: -0.6cm))
    #block(width: 95%)[
      #set text(10pt)
      #set align(left)
      #set par(leading: 0em, justify: false)
      Notes: The figure shows the spatial distribution of all patents in the matched sample in 100 hexagonal bins. The colours are in the log scale.]
  ],
  caption: [
    #set text(size: 10pt)
    Binned patent distribution
  ]
) <figure2>

= Results <section4>

= Conclusion <section5>

#pagebreak()

#bibliography("bibliography.bib", style: "harvard-cite-them-right")