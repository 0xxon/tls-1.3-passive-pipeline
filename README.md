Passive pipeline description
============================

This is the description of the passive measurement pipeline for the TLS 1.3 measurement submission to CCR.

For our passive TLS 1.3 measurements, we cannot release the dataset. We are bound by agreements with our data providers; in our case we cannot provide the raw data or any part of it. We can only provide high-level statistics - as given in the paper.

We are, however, able to publish the entirety of our passive measurement pipeline, which is documented here.

Docker container
----------------

The easiest way to get the passive measurement pipeline up and running is via docker.

Just run ```docker run -i -t "0xxon/zeek-tls-1.3-research:ccr"```, followed by ```su - tls```, and you will be dropped into an environment that has all necessary utilities and prerequisites installed.

For the rest of this guide we will assume that you are using the docker container. However, we will also give pointers in the individual sections how you can install all the required software manually; alternatively you can take a look at the ```Dockerfile``` contained in this repository.

Data & log file generation
--------------------------

The first step of the passive measurement pipeline is data generation - measuring information about TLS deployments from Internet traffic.

To this end, we use the [Zeek Network Monitor](https://zeek.org), in version 3.0.0, together with a custom logging script which is available at https://github.com/0xxon/zeek-tls-log-alternative.

To test this part of the pipeline in our Docker container, just run zeek against a trace-file. For example, you can issue

```zeek packages -r /root/build/zeek/testing/btest/Traces/tls/tls13draft23-chrome67.0.3368.0-canary.pcap```

After running this, you should see a few ```.log``` files in the current directory, including a file called ```tls.log```. This file contains all the metainformation that is necessary to reproduce our study.

For an in-depth description of all the fields, please see [the tls.zeek script](https://github.com/0xxon/zeek-tls-log-alternative/blob/master/scripts/tls.zeek).

In our case, the measurement pipeline is run on real-world traffic. Setting up a data collection pipeline on a larger Internet link will require some resources and time. If you want to start this collection on your own, on youw own server you will have to:

* install Zeek on a suitable server, which gets a copy of the Internet traffic that you want to monitor. Zeek installation instructions are given at https://docs.zeek.org/en/stable/install/install.html. Note: for larger Internet uplinks you will want to deploy Zeek in cluster mode and use AF_PACKET or PF_RING to distribute your traffic accross worker nodes.
* install the logging script from https://github.com/0xxon/zeek-tls-log-alternative, using the zeek package manager.

Afterwards you should get the same ```tls.log``` from your installation


Log file ingestion
------------------

The next step after data generation is to load the log files into a database. In our project, we load the logs into PostgreSQL, using a [custom log ingestion pipeline](https://github.com/0xxon/zeek-tls-log-alternative-parser).

On the docker container, everything is pre-installed. Just ```cd``` to the directory ```zeek-tls-log-alternative-parser```. In this directory you will find a script ```createTestEnvironment.sh```. Calling this script will:

* create a new, empty PostgreSQL instance in the local directory and start it up
* create a database called ```tls``` in the PostgreSQL instance
* call the script that creates the required table
* import two example log files into the database

After running this script, a postgres server with 2 imported data files is running locally on port 7779. To connect to it, use ```psql -p 7779 tls```.

Looking at the database shows one table, called seen_stats.

```
tls@476e492ebc02:~/zeek-tls-log-alternative-parser$ psql -p 7779 tls
psql (11.5 (Debian 11.5-1+deb10u1))
Type "help" for help.

tls=# \d
               List of relations
 Schema |       Name        |   Type   | Owner
--------+-------------------+----------+-------
 public | seen_stats        | table    | tls
 public | seen_stats_id_seq | sequence | tls
(2 rows)

tls=#
```

This table contains all collected information. A lot of it is stored in the PostgreSQL hstore datatpe - which has a bit unusual query syntax. See [the PostgreSQL manual on hstores](https://www.postgresql.org/docs/12/hstore.html) for details.

For example, to query all negotiated versions that were seen in your dataset, you could use the following query:

```
with a as (
 select (each(selected_version)).key as version,
        (each(selected_version)).value::integer as count from seen_stats
)
select sum(count), version from a group by version; 
```

You can destroy the local PostgreSQL instance by calling the ```deleteTestEnvironment.sh``` script. If you want to test the query scripts, leave it running.

To set this pipeline up on your own server, you will
* need a reasonably new version os PostgreSQL (10+)
* need a reasonably new installation of Perl, to which you can install new packages using CPAN
* install all the packages mentioned at https://github.com/0xxon/zeek-tls-log-alternative-parser; this can be accomplished by calling the ```install-prereqs.sh``` script.
* set up the database like in the ```createTestEnvironment.sh``` script - then call ```CertReader::App::Readseen``` for all of your log-files just as shown in this script.

Evaluation
----------

Our evaluation is done directly from the data in the database using a [custom script, which can output its results as LaTeX code](https://github.com/0xxon/postgres-to-latex).

Once again, this is preinstalled in the docker container. Change the directory to ```/home/tls/postgres-to-latex```. If you still have the example database of the last section running, you can just run:

```
# copy the query file that was used for the paper
cp examples-tls-research/queries.yaml .
./executeQueries.pl
mv results-new.yaml results.yaml
./generateTex.pl > output.tex
```

and you will have the result of the queries in the file output.tex. If you examine the file ```examples-tls-research/queries.yaml``` you will see the queries in the file, which were used as a basis to generate the tables in the paper. Other numbers in the paper were generated using one-off queries.

To use this on your own system, just clone https://github.com/0xxon/postgres-to-latex.