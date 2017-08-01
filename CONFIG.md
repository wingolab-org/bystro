# The Bystro configuration file
#### TL;DR: A YAML config file that idempotently describes both database creation and annotation output. Used to build a new database, run an annotation, or precisely replicate a prior experiment

Templates of every Bystro configuration used on https://bystro.io is found in the config folder as <assembly>.clean.yml
  - To use them, simply update the `database_dir` property (described below) to the one that contains the `index` folder of your downloaded database (Database download, setup information found in [INSTALL.md](INSTALL.md))
  
## Overview
Each Bystro configuration file has several required keys:
  - `assembly`: (String) The genome assembly (ex: `hg38`). This is an arbitrary value used to identify the config file
 
    Ex:
    
    ```yaml
    assembly: hg38
    ```
  - `chromosomes`: (Array) The allowable chromosomes (during annotation and building)
    
    Ex:
    ```yaml
    chromosomes:
    - chr1
    - chr2
    - chr3
    ```

  - `tracks`: (Array[Seq::Tracks]> What we include in our database during **building**, and what we output during **annotation**
  
    Ex:
    
    ```yaml
    tracks:
    - build_author: Alex Kotlar
      build_date: 2017-04-22T05:22:00
      fetch_date: 2017-02-09T16:56:00
      local_files:
      - chr*.fa.gz
      name: ref
      remote_dir: http://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/
      remote_files:
      - chr1.fa.gz
      - chr2.fa.gz
      # Etc
      type: reference
      version: 46
     ```
  
  - `database_dir`: (String) The directory in which the Bystro database should/does reside
  
    Ex:
    ```yaml
    database_dir: /bystro/hg38/index/
    ```

It has several optional keys:
  - `files_dir`: (String) Where database source files are located (required only during building new db)
  
    Ex:
    ```yaml
    files_dir: /bystro/hg38/raw/
    ```
  
  - `statistics`: (String) (optional) Statistics package config. Defines features tr/tv stats generated on
  
    Ex:
    ```yaml
    statistics:
      dbSNPnameField: dbSNP.name
      exonicAlleleFunctionField: refSeq.exonicAlleleFunction
      outputExtensions:
        json: .statistics.json
        qc: .statistics.qc.tsv
        tab: .statistics.tsv
      refTrackField: ref
      siteTypeField: refSeq.siteType
      programPath: bystro-stats
    ```
    - The default `programPath` is `bystro-stats`.
    - You can plug your own program as long as it conforms to the `bystro-stats` interface
  
  - `snpProcessor`: (String) (optional) The program that is used to process `.snp` files and generate an intermediate annotation
    
    Ex:
    ```yaml
    snpProcessor: bystro-snp
    ```
    
    - Default is `bystro-snp`. You can plug your own, as long as it conforms to the `bystro-snp`interface
  
  - `vcfProcessor`: (String) (optinal) The program that is used to process `.vcf` files and generate an intermediate annotation
    
    Ex:
    ```yaml
    vcfProcessor: bystro-vcf
    ```
    
    - Default is `bystro-vcf`. You can plug your own, as long as it conforms to the `bystro-vcf` interface

And several meta fields that are automatically generated after every build: 
  - `build_author`: (String) (after build) The user that created this database
  
  - `build_date`: (String) (after build) The date this database was created
  
  - `version`: (String) (after build) The database version
  
  
These meta fields are also generated for each track that is built, so that track version can segregate independently.
    

## Directories
#### TL;DR: Where the Bystro database, source files, and scratch folders are located

1. `files_dir`: (String) The parent folder within which each track's ```local_files``` are located
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

2. `database_dir`: (String) Each database is held within ```database_dir```, in a folder of the name ```assembly```
  
    **Ex:** For the config file containing
    ```yaml
    assembly: hg19
    database_dir: /path/to/databases/
    ```
 
     Bystro will look for the database ```/path/to/databases/hg19```

3. `temp_dir`: <(String) When not non-null (not `~`), Bystro will write all output files to this dir, before moving them to the final destination, as defined by the ```--out``` argument in `bin/annotate.pl`.
  
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

## Chromosomes (String)
#### TL;DR: What chromosomes Bystro will build and annotate

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
        - `chr .` can be interpreted as the perl command:
        ```perl
        $chrom = "chr" . $chrom
        ```
      
      Note: `fieldMap` allows us to rename header fields to conform with the interface of that track type 
        - `sparse` tracks require the fields `chrom`, `chromStart`, `chromEnd`, but will accept any fieldMap transformations
        - Here we transform the Clinvar fields Chromosome, Start, Stop to `chrom`, `chromStart`, `chromEnd`

## Tracks (Array[Seq::Tracks])
#### TL;DR: The fields Bystro will build and annotate

The `tracks` property is an `Array` of tracks conforming to the `Seq::Tracks` package interface

#### Each track automatically inherits top-level YAML config properties, such as `chromosomes`, `database_dir`, etc
  - This allows each track to be configured as a self-contained module, while keeping all Bystro modules coordinated
  - For instance, `databse_dir`, `files_dir`. and `chromosomes` are needed by all tracks, and automatically available
  - Another example is the `vcfProcessor`. Both `Seq` and `Seq::Tracks::Vcf::Build` packages depends on it.

Required properties:
 1. `name` : The unique identifier for this track
 2. `type` : One of `sparse`, `gene`, `score`, `cadd`. Which you choose depends on your source file:
   - **sparse**: For .bed files, or any file that has 3 columns that can be mapped to chrom, chromStart, and chromEnd.
        - Our example configuration use this for dbSNP, and Clinvar records
        
        - The source file **must** have a header.
        - However, it doesn't need to have columns named '**chrom**', '**chromStart**', and '**chromEnd**', as long as there are 3 columns (by any name) containing chromosome, start, and stop information
          - Any header fields can be renamed using the ```fieldMap``` property
          
          Ex: Clinvar calls its relevant columns `Chromosome`, `Start, and `Stop`. To use this source file, simply:
          ```yaml
          tracks:
            - name: clinvar
              type: sparse
              fieldMap:
                Chromosome: chrom
                Start: chromStart
                Stop: chromEnd
          ```
  
    - **score**: Any wigFix file. 
      - Ex: UCSC phastCons: http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phastCons100way/hg38.100way.phastCons/
    
    - **cadd**: A CADD file (http://cadd.gs.washington.edu), or Bystro's .bed-like CADD file
        - Bystro's "bed-like" CADD file used to ease liftOver to hg38.
          - Currently waiting on UoW permission to share this file.
          - The format has the header
          ```tab
          ## CADD v1.3 (c) University of Washington and Hudson-Alpha Institute for Biotechnology 2013-2015. All rights reserved.
          chrom	chromStart	chromEnd	Ref	Alt	RawScore	PHRED
          ```

          This allows lifTover to occur with a simple command:
          ```shell
          tail -n +3 /path/to/file | liftOver -bedPlus=3
          ```
          - The standard CADD format is:
          ```tab
          ## CADD v1.3 (c) University of Washington and Hudson-Alpha Institute for Biotechnology 2013-2015. All rights reserved.
          #Chrom  Pos     Ref     Alt     RawScore        PHRED
          ```

    - **gene**: A UCSC gene track field (ex: knownGene, refGene, sgdGene).
        - The source files for this are generated using an `sql_statement`:
        
        Ex:
        ```yaml
        - name: refSeq
          type: gene
          sql_statement: SELECT * FROM hg38.refGene LEFT JOIN hg38.kgXref ON hg38.kgXref.refseq = hg38.refGene.name
        ```
### General Track Configuration Properties
1. `remote_dir`: (String) and `remote_files` (String). The online (remote) directory in which `remote_files` are located

Ex: The phyloP track configuration shows this clearly:

```yaml
name: phyloP
type: score
remote_dir: http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phyloP100way/hg38.100way.phyloP100way/
remote_files:
  - chr1.phyloP100way.wigFix.gz
  - chr2.phyloP100way.wigFix.gz
  - chr3.phyloP100way.wigFix.gz
  - chr4.phyloP100way.wigFix.gz
  # Etc
```

Remote files can be used without remote_dir, provided that the absolute path is used. Going by the previous example, we could have entered:

```yaml
name: phyloP
type: score
remote_files:
  - http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phyloP100way/hg38.100way.phyloP100way/chr1.phyloP100way.wigFix.gz
  - http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phyloP100way/hg38.100way.phyloP100way/chr2.phyloP100way.wigFix.gz
  - http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phyloP100way/hg38.100way.phyloP100way/chr3.phyloP100way.wigFix.gz
  - http://hgdownload.cse.ucsc.edu/goldenPath/hg38/phyloP100way/hg38.100way.phyloP100way/chr4.phyloP100way.wigFix.gz
  # Etc
```

Remote files are fetched using the Utils::Fetch package.

Ex: For the above configuration, we would run

```shell
bin/run_utils --fetch --name phyloP config/hg38.yml
```

Which would generate a series of local_files in `files_dir`/phyloP/ and the following configuration file update:

```yaml
name: phyloP
type: score
local_files:
  - chr1.phyloP100way.wigFix.gz
  - chr2.phyloP100way.wigFix.gz
  - chr3.phyloP100way.wigFix.gz
  - chr4.phyloP100way.wigFix.gz
  # Etc
```

2. ```local_files```: (Array) The source files on disk corresponding to this track
  - This property is automatically filled when using a Utils package to fetch 
