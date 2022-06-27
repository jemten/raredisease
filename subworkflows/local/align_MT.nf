//
// Prepare bam files for MT allignment
//

include { BWAMEM2_MEM as BWAMEM2_MEM_MT                         } from '../../modules/nf-core/modules/bwamem2/mem/main'
include { GATK4_MERGEBAMALIGNMENT as GATK4_MERGEBAMALIGNMENT_MT } from '../../modules/nf-core/modules/gatk4/mergebamalignment/main'
include { PICARD_MARKDUPLICATES as PICARD_MARKDUPLICATES_MT     } from '../../modules/nf-core/modules/picard/markduplicates/main'
include { SAMTOOLS_INDEX as SMATOOLS_INDEX_MT                   } from '../../modules/nf-core/modules/samtools/index/main'
include { HAPLOCHECK as HAPLOCHECK_MT                           } from '../../modules/nf-core/modules/haplocheck/main'
include { GATK4_MUTECT2 as GATK4_MUTECT2_MT                     } from '../../modules/nf-core/modules/gatk4/mutect2/main'

workflow ALIGN_MT {
    take:
        fastq  // Fastq
        ubam   // unmapped bam
        index  // channel: [ /path/to/bwamem2/index/  ]
        fasta  // channel: [genome.fasta]
        dict   // channel: [genome.dict]
        fai    // channel: [genome.fai]
        intervals_mt //intervals of MT

    main:
        ch_versions = Channel.empty()

        // Outputs bam files
        BWAMEM2_MEM_MT ( fastq , index, true)
        ch_versions    = ch_versions.mix(BWAMEM2_MEM_MT.out.versions.first())
        ch_mt_bam      =  BWAMEM2_MEM_MT.out.bam
        ch_fastq_ubam  = ch_mt_bam.join(ubam, by: [0])

        // Merges bam files
        GATK4_MERGEBAMALIGNMENT_MT ( ch_fastq_ubam, fasta, dict )
        ch_versions = ch_versions.mix(GATK4_MERGEBAMALIGNMENT_MT.out.versions.first())

        // Marks duplicates
        PICARD_MARKDUPLICATES_MT ( GATK4_MERGEBAMALIGNMENT_MT.out.bam )
        

        ch_bam_markdup = PICARD_MARKDUPLICATES_MT.out.bam
        ch_versions = ch_versions.mix(PICARD_MARKDUPLICATES_MT.out.versions.first())
        
        // Index bam file
        SMATOOLS_INDEX_MT(PICARD_MARKDUPLICATES_MT.out.bam)
        ch_bai = Channel.fromPath(SMATOOLS_INDEX_MT.out.bai)
        ch2=PICARD_MARKDUPLICATES_MT.out.bam.join(ch_bai, by: [0])
        //ch3=ch2.join([], by:[0])


        ch_versions = ch_versions.mix(SMATOOLS_INDEX_MT.out.versions.first())
        
        
        //PICARD_MARKDUPLICATES_MT.out.bam
        //.map {meta, bam -> 
		//	return[meta,bam,SMATOOLS_INDEX_MT.out.bai, intervals_mt]
        //    }.set {ch3}


        // Calls variants with Mutect2
        GATK4_MUTECT2_MT ( [ch2, intervals_mt ], fasta, fai, dict, [], [], [], [] )
        ch_versions = ch_versions.mix(GATK4_MUTECT2_MT.out.versions.first())

        // Haplocheck
        HAPLOCHECK_MT ( GATK4_MUTECT2_MT.out.vcf )
        ch_versions = ch_versions.mix(HAPLOCHECK_MT.out.versions.first())


    emit:
        vcf      = GATK4_MUTECT2_MT.out.vcf
        tbi      = GATK4_MUTECT2_MT.out.tbi
        txt      = HAPLOCHECK_MT.out.txt
        html     = HAPLOCHECK_MT.out.html
        versions = ch_versions // channel: [ versions.yml ]
}
