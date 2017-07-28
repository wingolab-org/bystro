# The Bystro configuration file
<h4>TL;DR: An idempotent YAML config file that completely describes both database and annotation output, and is used to build a new database, run an annotation, or exactly replicate a prior experiment</h4>

It has several required keys:
  - `assembly`: The genome assembly (ex: `hg38`). This is an arbitrary value used to identify the config file
 
  - `chromosomes`: The allowable chromosomes (during annotation and building)
  
  - `tracks`: What we include in our database during **building**, and what we output during **annotation**
  
  - `database_dir`: The directory in which the Bystro database should/does reside

It has several optional keys:
  - `files_dir`: (optional for annotation, required during building) Where database source files are located
  
  - `statistics`: (optional) The configuration of the statistics package. Defines which features we generate tr/tv stats on
    - Default statistics program (`programPath`) is `bystro-stats`. You can plug your own as long as it conforms to the `bystro-stats` interface
  
  - `snpProcessor`: (optional) The program that is used to process `.snp` files and generate an intermediate annotation
    - Default is `bystro-snp`. You can plug your own, as long as it conforms to the `bystro-snp`interface
  
  - `vcfProcessor`: (optinal) The program that is used to process `.vcf` files and generate an intermediate annotation
    - Default is `bystro-vcf`. You can plug your own, as long as it conforms to the `bystro-vcf` interface

And several meta fields (this is the only non-idempotent bit): 
  - `build_author`: (after build) The user that created this database
  
  - `build_date`: (after build) The date this database was created
  
  - `version`: (after build) The database version
    

## Directories and Files
<h4>TL;DR: Where the Bystro database, source files, and scratch folders are located</h4>

1. `files_dir` : The parent folder within which each track's ```local_files``` are located
  * Bystro automatically checks for ```local_files``` at ```parent/trackName/file```
    
    **Ex:** For the config file containing
    ```yaml
    files_dir: /path/to/files/
    track:
      - name: refSeq
        local_files:
          - hg19.refGene.chr1.gz
          # and more files
     ```
       Bystro will expect files in ```/path/to/files/refSeq/hg19.refGene.chr1.gz```

2. `database_dir` : Each database is held within ```database_dir```, in a folder of the name ```assembly```
  
    **Ex:** For the config file containing
    ```yaml
    assembly: hg19
    database_dir: /path/to/databases/
    ```
 
     Bystro will look for the database ```/path/to/databases/hg19```

3. `temp_dir` : When this value is non-null (not ```~```), Bystro will write all files initially to a temporary directory, before moving them to the final destination (defined by the ```--out``` argument when submitted on the command line)
  
    **Ex**: For the config file containing
    ```yaml
    assembly: hg38
    temp_dir: /path/to/dir
    ```
    and the command 
    ```sh
    bin/annotate.pl --in /some/file.vcf.gz --config config/hg38.yml --out /some/dir/outPrefix
    ```
    All files will first be written to a random-number-generated folder within /path/to/dir before being moved to /some/dir as:
      - /some/dir/outPrefix.annotation.tsv
      - /some/dir/outPrefix.annotation.log.txt
      
    This is useful when /path/to/dir is mounted on a significantly more performant disk than /some/dir
    - `temp_dir` is best used with the ```--compress``` runtime argument
    - when `--compress` is used (```bin/annotate.pl --compress```), the temporary file will be generated in compressed form, allowing small, fast, scratch disks to be used.
      - annotations often compress by a factor of ~10-30x
      - so a `temp_dir` disk of ~100GB is enough for practically any annotation when in `--compress` is set

## Chromosomes
<h4>TL;DR: What chromosomes Bystro will build and annotate</h4>

Input and and database source records are foremost identified by their chromosome and position.
Therefore, we must agree on the acceptable chromosomes during database building, and then allow only these during annotation

Bystro currently expects UCSC conventions for chromosome names, meaning they should be prepended by **chr** (`chrN`).
  - To make life easier, during *annotation* Bystro will add a `chr` prefix to each input row's chromosome as needed.
  
    **Ex:** For the following config
    ```yaml
    chromosomes:
    - chr1
    - chr2
    - chr3
    ```
    
    Only chr1, chr2, and chr3 will be accepted during building, and only chr1, chr2, chr3, or 1, 2, 3 will be accepted during *annotation*.
 
 However, to reduce this restriction during *building*, Bystro provides general capacity to transform db source fields.
   - This is done using the `build_field_transformations` property for any track in the `tracks` YAML array
   
      Ex: Clinvar chromosomes don't have a **chr** prefix, so during building we specify:
      ```yaml
      tracks:
        - name: clinvar
          type: sparse
          build_field_transformations:
            chrom: chr .
          fieldMap:
            Chromosome: chrom
            Start: chromStart
            Stop: chromEnd
      ```
      
      Here ```build_field_transformations``` allows us to define a prepend operation:
        - ```chr .``` can be interpreted as the perl command ``` "chr" . $chrom```
      
      Note: ```fieldMap``` allows us to rename header fields to conform with the interface of that track type 
        - `sparse` tracks require the fields `chrom`, `chromStart`, `chromEnd`, but will accept any fieldMap transformations
        - Here we transform the Clinvar fields Chromosome, Start, Stop to `chrom`, `chromStart`, `chromEnd`
      
      
    So: input files do **not** need to have their chromosomes prepended by **chr**. Bystro will normalize the name.
    
    In this example chromosomes ```1``` and ```chr1``` will be built/annotated, but ```1_rand``` will not.
## Tracks
<h4>TL;DR: The fields Bystro will build and annotate</h4>

Tracks have a ```name``` property, which must be unique, and a ```type```, which must be one of:
      + *sparse*: Any bed file, or any file that can be mapped to chrom, chromStart, and chromEnd columns.
        + This is used for dbSNP, and Clinvar records, but many files can be fit this format.
        + Mapping fields can be managed by the ```fieldMap``` key
      + *score*: Accepts any wigFix file. 
        + Used for phastCons, phyloP
      + *cadd*:
        + Accepts any CADD file, or Bystro's custom "bed-like" CADD file, which has 2 header lines, and chrom, chromStart, chromEnd columns, followed by standard CADD fields
        * CADD format: http://cadd.gs.washington.edu
      + *gene*: A UCSC gene track field (ex: knownGene, refGene, sgdGene).
        + The ```local_files``` for this are created using an ```sql_statement```
        + Ex: ```SELECT * FROM hg38.refGene LEFT JOIN hg38.kgXref ON hg38.kgXref.refseq = hg38.refGene.name```
