process ENSEMBLVEP {
    tag "$meta.id"
    label 'process_medium'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used with vep at the moment. Please use Docker or Singularity containers."
    }

    container "ensemblorg/ensembl-vep:release_107.0"

    input:
    tuple val(meta), path(vcf)
    val   genome
    val   species
    val   cache_version
    path  cache
    path  fasta
    path  extra_files

    output:
    tuple val(meta), path("*.ann.vcf")     , optional:true, emit: vcf
    tuple val(meta), path("*.ann.tab")     , optional:true, emit: tab
    tuple val(meta), path("*.ann.json")    , optional:true, emit: json
    tuple val(meta), path("*.ann.vcf.gz")  , optional:true, emit: vcf_gz
    tuple val(meta), path("*.ann.tab.gz")  , optional:true, emit: tab_gz
    tuple val(meta), path("*.ann.json.gz") , optional:true, emit: json_gz
    path "*.summary.html"                  , optional:true, emit: report
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def file_extension = args.contains("--vcf") ? 'vcf' : args.contains("--json")? 'json' : args.contains("--tab")? 'tab' : 'vcf'
    def compress_out = args.contains("--compress_output") ? '.gz' : ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def stats_file     = args.contains("--no_stats") ? '' : "--stats_file ${prefix}.summary.html"
    def dir_cache = cache ? "\${PWD}/${cache}" : "/.vep"
    def reference = fasta ? "--fasta $fasta" : ""

    """
    vep \\
        -i $vcf \\
        -o ${prefix}.ann.${file_extension}${compress_out} \\
        $args \\
        $reference \\
        --assembly $genome \\
        --species $species \\
        --cache \\
        --cache_version $cache_version \\
        --dir_cache $dir_cache \\
        --fork $task.cpus \\
        ${stats_file}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ensemblvep: \$( echo \$(vep --help 2>&1) | sed 's/^.*Versions:.*ensembl-vep : //;s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.ann.vcf
    touch ${prefix}.ann.tab
    touch ${prefix}.ann.json
    touch ${prefix}.ann.vcf.gz
    touch ${prefix}.ann.tab.gz
    touch ${prefix}.ann.json.gz
    touch ${prefix}.summary.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ensemblvep: \$( echo \$(vep --help 2>&1) | sed 's/^.*Versions:.*ensembl-vep : //;s/ .*\$//')
    END_VERSIONS
    """
}
