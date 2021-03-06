% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rupture_scaling.R
\name{Mw_2_rupture_size_inverse}
\alias{Mw_2_rupture_size_inverse}
\title{Compute the inverse of Mw_2_rupture_size, given area as an input}
\usage{
Mw_2_rupture_size_inverse(area, relation = "Strasser", CI_sd = 0)
}
\arguments{
\item{area}{numeric area}

\item{relation}{Type of scaling relation used (e.g. 'Strasser', see ?Mw_2_rupture_size)}

\item{CI_sd}{numeric (can be positive or negative). Positive values correspond to
lower Mw, negative values to higher Mw.}
}
\value{
values of Mw
}
\description{
Given an area, this function computes the Mw value such that
\code{Mw_2_rupture_size(Mw, relation=relation, detailed=TRUE, CI_sd = CI_sd) = area}. 
It currently does not give information on length or width.
}
\examples{
   for(Mw in c(8.0, 8.67, 9.0)){
       for(relation in c('Strasser', 'AllenHayes')){
           Mw = 8.0
           # Get detailed information on the expected rupture size range
           area0 = Mw_2_rupture_size(Mw, relation=relation, detailed=TRUE, CI_sd = 2)
           # Find Mw such that area0$values[1] is a lower 2-sigma area
           Mw_squeezed = Mw_2_rupture_size_inverse(area0$values[1], relation=relation, CI_sd = -2)
           # Confirm that it worked
           area1 = Mw_2_rupture_size(Mw_squeezed, relation=relation, detailed=TRUE, CI_sd = 2)
           # The minus_CI component of area1 should equal area0
           stopifnot(abs(area1$minus_CI[1] - area0$values[1]) < 1.0e-04)
       }
   }
}
