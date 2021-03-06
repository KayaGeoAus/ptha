% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/axpy_local.R
\name{axpy_local}
\alias{axpy_local}
\title{Interface to BLAS axpy}
\usage{
axpy_local(y, a, x)
}
\arguments{
\item{y}{matrix or array}

\item{a}{constant of length 1}

\item{x}{matrix or array with same length as y}
}
\value{
Nothing, but updates the value of y in-place
}
\description{
Replaces y with a*x + y. Both x and y must be double and have the same
length. On large arrays, this is faster than using R to do "y = a*x+y".\cr
BEWARE THAT THIS PERFORMS IN-PLACE UPDATE WHICH PROBABLY VIOLATES
YOUR EXPECTATIONS OF R CODE. For instance, the code \cr
\code{x = runif(10); z = runif(10); y = z; axpy_local(y, 2.0, x)} will cause
BOTH y and z to be updated by the axpy call! \cr
This occurs because R's reference counting scheme makes
z and y point to the same memory. To suppress this behaviour, replace the \cr
\code{y=z} line above with an operation, e.g. \cr
\code{y=z*1} \cr
 This will make R create new memory for y, so z will not be updated. \cr
While use of this routine requires some care, it can be 3x faster than doing
the same calculation in native R, so it is worthwhile for performance bottlenecks.
}
\examples{
y = 1.0*(1:10) # Make double
x = 1.0*(21:30) # Make double
axpy_local(y, 2.0, x)
stopifnot(all(abs(y - (2*(21:30) + 1:10)) < 1.0e-10))

}
