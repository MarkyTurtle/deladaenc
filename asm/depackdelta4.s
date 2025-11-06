

                        ; Perform delta4 decompression on a protracker module that has previously been
                        ; compressed using the 'deladaenc' 4bit delta compression utility found at:-
                        ; https://github.com/Hemiyoda/deladaenc
                        ;
                        ; 1) Set address register a0.l to the address of the loaded compressed module.
                        ; 2) Set address register a1.l to the address of a buffer large enough to hold the decompressed module.
                        ; 3) Call depackdelta4.
                        ;
                        ;       lea.l   compressed_module,a0
                        ;       lea.l   decompressed_buffer,a1
                        ;       jsr     depackdelta4
                        ;       ...
                        ;
                        ; IN:   
                        ;       a0 = delta4 compressed pt-module buffer ptr
                        ;       a1 = decompressed pt-module output buffer ptr
                        ;
depackdelta4:
                                movem.l d0-d7/a0-a6,-(a7)

                                move.l  a0,compressed_module_ptr
                                move.l  a1,decompressed_module_ptr

                                ; a0 = delta4 compressed buffer ptr
                                jsr     find_sample_offset
                                move.l  d0,compressed_sample_offset             ; save byte offset to start of compressed sample data (from start of compressed_module_ptr)
                                
                                ; a0 = delta4 compressed buffer ptr
                                ; d0.l = compressed sample byte offset
                                jsr     get_original_sample_length              ; obtain the original sample length from the compressed sample data
                                move.l  d0,original_sample_length

                                ; a0 = delta4 compressed buffer ptr
                                ; a1 = decompressed output buffer ptr
                                ; d0.l = compressed sample data start byte offset
                                move.l  compressed_sample_offset,d0
                                jsr     copy_song_data
                                move.l  a0,compressed_sample_ptr
                                move.l  a1,uncompressed_sample_ptr

                        ; uncompress the sample data
                                ; a0 = delta4 compressed buffer ptr
                                ; a1 = decompressed output buffer ptr
                                ; d0.l = compressed sample data start byte offset
                                lea     $10(a0),a2                              ; get lookup table ptr (16 bytes from start of compressed sample data) 
                                move.l  a2,lookup_table_ptr

                                lea     $1000(a2),a3                             ; get first sample byte ptr (4096 bytes from start of lookup table data)
                                move.l  a3,first_compressed_sample_ptr

                                move.l  original_sample_length,d7
                                move.l  d7,d5                                   ; expected max length of decompressed bytes (comparison value)
                                move.l  #0,d4                                   ; count of decompressed bytes
                                sub.l   #1,d7                                   ; max loop counter (will exit if -1 on dbf of outer loop)

                                move.l  first_compressed_sample_ptr,a0
                                move.l  uncompressed_sample_ptr,a1
                                move.l  lookup_table_ptr,a3

                                ; copy first sample byte
                                move.l  #0,d3
                                move.b  (a0)+,d3                                ; d3 is used as the accumulated sample value
                                move.b  d3,(a1)+

.outer_loop
                                ; check if decompression completed
                                cmp.l   d4,d5
                                beq     .exit_decompression                     ; exit if expected number of bytes decompressed
                                bcs     .exit_decompression                     ; exit if more than expected number of bytes decompressed

                                ; get lookup set byte and offset
                                move.l  #0,d0           
                                move.b  (a0)+,d0
                                mulu    #16,d0                                  ; 16 bytes per delta lookup set

                                move.l  #8-1,d6                                 ; 8 bytes per compressed data frame (16 nibbles of 4bnit deltas)
.inner_loop_d6          
                                ; check if decompression completed
                                cmp.l   d4,d5
                                beq     .exit_decompression                     ; exit if expected number of bytes decompressed
                                bcs     .exit_decompression                     ; exit if more than expected number of bytes decompressed

                                ; decompress nibble1
                                move.l  #0,d1
                                move.b  (a0),d1
                                lsr.b   #4,d1
                                add.l   d0,d1                                   ; add delta 4 value to lookup set index
                                add.b   (a3,d1.l),d3                            ; add lookup table delta value to current sample value
                                move.b  d3,(a1)+                                ; store decompressed 8 bit value
                                add.l   #1,d4                                   ; increment decompressed sample count

                                ; check if decompression completed
                                cmp.l   d4,d5
                                beq     .exit_decompression                     ; exit if expected number of bytes decompressed
                                bcs     .exit_decompression                     ; exit if more than expected number of bytes decompressed

                                ; decompress nibble2
                                move.l  #0,d1
                                move.b  (a0)+,d1
                                and.b   #$0f,d1
                                add.l   d0,d1                                   ; add delta 4 value to lookup set index
                                add.b   (a3,d1.l),d3                            ; add lookup table delta value to current sample value
                                move.b  d3,(a1)+                                ; store decompressed 8 bit value
                                add.l   #1,d4                                   ; increment decompressed sample count

                                dbf     d6,.inner_loop_d6                       ; loop to decompress 16 nibble frame
                                bra     .outer_loop                             ; loop until all sample data frames have been decompressed
.exit_decompression  
                                movem.l (a7)+,d0-d7/a0-a6
                                rts



                        ; IN:   a0 = delta4 compressed buffer ptr
                        ;       a1 = decompressed output buffer ptr
                        ;       d0.l = compressed sample data start byte offset
                        ; OUT:  a0 = compressed sample data start ptr
                        ;       a1 = decompressed sample data start ptr
                        ;       d0.l = compressed sample data start byte offset
copy_song_data
                                movem.l d1-d7/a2-a6,-(a7)

                                move.l  d0,d7
                                sub.l   #1,d7
.copy_loop
                                move.b  (a0)+,(a1)+
                                dbf     d7,.copy_loop
                                
                                movem.l (a7)+,d1-d7/a2-a6
                                rts


                        ; IN:   a0 = delta 4 compressed buffer ptr
                        ;       d0.l = byte offset to start of compressed sample data
                        ; OUT:  d0.l = original sample data length
get_original_sample_length
                        movem.l d1-d7/a0-a6,-(a7)

                        move.l  #0,d1
                        move.b  5(a0,d0.l),d1
                        rol.l   #8,d1
                        move.b  6(a0,d0.l),d1
                        rol.l   #8,d1
                        move.b  7(a0,d0.l),d1

                        move.l  d1,d0

                        movem.l (a7)+,d1-d7/a0-a6
                        rts


                        ; IN:   a0 = delta 4 compressed buffer ptr
                        ; OUT:  d0.l = byte offset to start of compressed sample data
                        ;       d1.l = highest pattern index number found
find_sample_offset
                                movem.l d2-d7/a0-a6,-(a7)

                                lea     $3b8(a0),a1                             ; offset 952 decimal = start of pattern play order data
                                move.l  #128-1,d7                               ; max song length = 128 patterns
                                move.l  #0,d1
                                move.l  #0,d2
.highest_loop                   
                                move.b  (a1)+,d1                                ; next pattern index number
                                cmp.b   d1,d2
                                bcc.s   .not_highest
.is_highest                     
                                move.b  d1,d2                                 ; store highest pattern found so far..
.not_highest
                                dbf     d7,.highest_loop                        ; loop through all patterns and find the highest index (d2)

                                move.l  #0,d0
                                move.l  #0,d1
                                move.b  d2,d0                                   ; store highest pattern number
                                move.b  d2,d1                                   ; store highest pattern number (d1)

                                mulu    #1024,d0                                ; calc sample start byte offset (d0)
                                add.l   #1024,d0
                                add.l   #1084,d0                                

                                movem.l (a7)+,d2-d7/a0-a6
                                rts



compressed_module_ptr           dc.l    0                       ; ptr to the start of the compressed module buffer
decompressed_module_ptr         dc.l    0                       ; ptr to the start of the decompressed module buffer

first_compressed_sample_ptr     dc.l    0
lookup_table_ptr                dc.l    0
uncompressed_sample_ptr         dc.l    0                       ; ptr to the start of the uncompressed samples in the decompressed module buffer
compressed_sample_ptr           dc.l    0                       ; ptr to the start of the compressed samples in the delta 4 compresseed module buffer
original_sample_length          dc.l    0                       ; the byte length of the uncompressed samples
compressed_sample_offset        dc.l    0                       ; the byte offset to the delta 4 compressed samples in the delta 4 compressed module buffer
