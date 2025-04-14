== Conceptual Framework

== Data and Empirical Strategy

=== Patents and patent citations

Explain the point of patents?

=== Sample construction

I use data from the PatentsView platform, which is a project supported by the Office of the Chief Economist at the USPTO.
The PatentsView data consists of processed patent data continuously updated with new releases of the USPTOP raw data.
The processing includes desambiguating entities (e.g., inventors and assignees) and standardising locations using OpenStreetMap (OSM) data.
The data is served either through bulk download files or an API.

I first fetch the patent data including identifiers, inventors, assignees, abstracts, application and grant dates, inventor order in the patent, and inventor location using the API.
I restrict the data to patents with at least one US inventor and a single corporate US assignee.
The latter restriction avoids multinational-companies registered in different countries as being considered separate.
That is, as highlighted in (CITE), Mitsubishi US and Mistubishi Japan something something.
This case could possibly not reflect a true spillover since...

I further process the patents to remove any missing values (HOW MANY) and patents with abstracts smaller than the 1st quantile or larger than the 99th quantile.
Missing values are likely caused by errors in the API, so consider them missing at random.
FOOTNOTE: I assert this since the missingness changed when request the same data at separate instances.
I trim the bottom abstracts since they are uninformative (e.g., the smallest abstracts had three characters) in matching.
The largest ones, although likely to be informative, would require embedding models with larger token limits, which would impose a significant computational burden for a very small subset of the data.

I select the set of originating patents as the ones granted in the first month of YEAR.
For each originating patent, I identify all citations within X YEARS of start date using the US citations bulk data from PatentsView.
I remove any self-citations, which include any patents with the same assignee or an inventor in common.
For each originating-citing pair I identify potential controls granted within the X YEAR period and with a application date within 6 months of the citing patent.
As before, I remove patents that, analogously to the self-cite case, has the same assignee or an inventor with common with the originating patent.

=== Embeddings

I collect all patents that are either a citing or a potential control and encode their abstracts.
An embeddings is... Probably goes somewhere up?
Hence, patents similarity is directly evaluated using...
Example here.
I use the nomic MODEL NAME since it has state-of the art performance and is open code and weights.
The abstracts are represented as a 256 dimensional vector.

Although... This could be improved.

I then select the top 0.1% most similar embeddings for each citing patent within all embedded patents using an approximate nearest neighbours search.
Hence, if there are N unique citing and control patents, the N/1000 nearest neighbours are selected.
I define the intersection of the potential controls previously defined and the nearest neighbours as the set of admissable controls.
Note that, in line with MURATA CITE, the set of admissable controls includes the citing patent itself.

=== Locations

Patents usually have multiple inventors, so there is not an unique patent location.
I define this location following Kerr and Kominers CITE as follows:

1. I restrict the set of potential locations to be within the US and select the most commonly occuring location
2. If there is more than one most commonly occuring location, I select that of the inventor with the lowest inventor sequence within the restricted set

For example patent X has location inventors in...

I then calculate the distance between each originating and citing and originating and control patent using the geodesic formula in kilometers.

=== Localisation test