#!/usr/bin/env node

const fs = require('fs');

// Load the quic.js module - create a module wrapper since it's not a proper Node.js module
let quicCode = fs.readFileSync('quic.js', 'utf8');

// Remove the export statement to make it compatible with eval
quicCode = quicCode.replace(/export\s*\{[^}]*\}[;\s]*$/, '');

// Create a global context for the JavaScript code to run in
global.encoder = null;

// Evaluate the QUIC JavaScript code
eval(quicCode);

function benchmarkDecode(filename, iterations = 100) {
    console.log(`JavaScript Benchmark: ${filename}`);
    console.log(`Iterations: ${iterations}`);
    
    try {
        // Read the binary file
        const binaryData = fs.readFileSync(filename);
        console.log(`File size: ${binaryData.length} bytes`);
        
        // Warm up run to eliminate JIT overhead
        console.log('Warming up...');
        for (let i = 0; i < 10; i++) {
            const result = encoder.simple_quic_decode(binaryData);
            if (!result) {
                throw new Error('Decode failed during warmup');
            }
        }
        
        // Benchmark runs
        console.log('Running benchmark...');
        const times = [];
        let totalBytes = 0;
        
        for (let i = 0; i < iterations; i++) {
            const startTime = process.hrtime.bigint();
            
            const result = encoder.simple_quic_decode(binaryData);
            
            const endTime = process.hrtime.bigint();
            const elapsedNs = Number(endTime - startTime);
            times.push(elapsedNs);
            
            if (!result) {
                throw new Error(`Decode failed on iteration ${i}`);
            }
            
            if (i === 0) {
                totalBytes = result.length;
                console.log(`Image: ${encoder.width}x${encoder.height}, type: ${encoder.type}`);
                console.log(`Output: ${result.length} bytes`);
            }
        }
        
        // Calculate statistics
        times.sort((a, b) => a - b);
        
        const minTime = times[0];
        const maxTime = times[times.length - 1];
        const medianTime = times[Math.floor(times.length / 2)];
        const avgTime = times.reduce((sum, time) => sum + time, 0) / times.length;
        
        // Convert nanoseconds to milliseconds for readability
        const toMs = (ns) => (ns / 1_000_000).toFixed(3);
        
        console.log('\n=== JavaScript Results ===');
        console.log(`Min time:    ${toMs(minTime)} ms`);
        console.log(`Max time:    ${toMs(maxTime)} ms`);
        console.log(`Median time: ${toMs(medianTime)} ms`);
        console.log(`Avg time:    ${toMs(avgTime)} ms`);
        console.log(`Throughput:  ${(totalBytes * iterations / (avgTime * iterations / 1_000_000_000) / 1024 / 1024).toFixed(2)} MB/s`);
        
        // Results already printed to console above
        
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

// Run benchmark
benchmarkDecode('test_data/quic_image_0.bin', 100);