process SENTIEON_DEDUP {
    tag "$meta.id"
    label 'process_high'
    label 'sentieon'

    input:
    tuple val(meta), path(bam), path(bai), path(score), path(score_idx)
    path fasta
    path fai

    output:
    tuple val(meta), path('*dedup.bam')          , emit: bam
    tuple val(meta), path('*dedup.bai')          , emit: bai
    tuple val(meta), path('*dedup_metrics.txt')  , emit: metrics_dedup
    path  "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def input  = bam ? '-i ' + bam.sort().join(' -i ') : ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    sentieon \\
        driver \\
        -t $task.cpus \\
        $input \\
        $args \\
        --algo Dedup \\
        --score_info $score \\
        --metrics ${prefix}_dedup_metrics.txt \\
        ${prefix}.dedup.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """

    stub:
    def prefix       = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.dedup.bam
    touch ${prefix}.dedup.bai
    touch ${prefix}_dedup_metrics.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sentieon: \$(echo \$(sentieon driver --version 2>&1) | sed -e "s/sentieon-genomics-//g")
    END_VERSIONS
    """
}
