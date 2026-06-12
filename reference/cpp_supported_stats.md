# Endogenous statistics with a compiled fast path

Returns the names of the endogenous statistics that
[`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md)
evaluates with the compiled C++ engine. Statistics outside this set are
computed by the (slower) pure-R fallback.

## Value

A character vector of statistic names.

## See also

[`compute_endogenous_features()`](https://franciscorichter.github.io/amore/reference/compute_endogenous_features.md)

## Examples

``` r
length(cpp_supported_stats())
#> [1] 66
head(cpp_supported_stats())
#> [1] "reciprocity"         "reciprocity_binary"  "reciprocity_count"  
#> [4] "transitivity_binary" "transitivity_count"  "cyclic_binary"      
```
