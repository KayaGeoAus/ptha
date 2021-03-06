% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gutenberg_richter_densities.R
\name{dGR}
\alias{dGR}
\title{Probability density function for Gutenberg Richter distribution}
\usage{
dGR(x, b, mw_min)
}
\arguments{
\item{x}{vector of quantiles}

\item{b}{Gutenberg-Richter b value}

\item{mw_min}{Minimum mw}
}
\value{
vector with probability densities at x
}
\description{
Note corresponding functions pGR, qGR, dGR, rGR. See ?rGR for an extended
example of fitting with maximum likelihood.
}
\examples{
# Compute the pdf of some random Mw values
random_Mw = rGR(10, b=0.8, mw_min = 6.0)
density_vals = dGR(random_Mw, b=0.8, mw_min=6.0)
}
