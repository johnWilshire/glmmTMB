% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/VarCorr.R
\name{sigma.glmmTMB}
\alias{sigma.glmmTMB}
\alias{sigma}
\title{Extract residual standard deviation or dispersion parameter}
\usage{
\method{sigma}{glmmTMB}(object, ...)
}
\arguments{
\item{object}{a \dQuote{glmmTMB} fitted object}

\item{\dots}{(ignored; for method compatibility)}
}
\description{
For Gaussian models, \code{sigma} returns the value of the residual
standard deviation; for other families, it returns the
dispersion parameter, \emph{however it is defined for that
particular family}. See details for each family below.
}
\details{
The value returned varies by family:
 \describe{
     \item{gaussian}{returns the \emph{maximum likelihood} estimate
         of the standard deviation (i.e., smaller than the results of
                                 \code{sigma(lm(...))} by a factor of (n-1)/n)}
     \item{nbinom1}{returns an overdispersion parameter
         (usually denoted \eqn{\alpha} as in Hardin and Hilbe (2007)):
         such that the variance equals \eqn{\mu(1+\alpha)}.}
     \item{nbinom2}{returns an overdispersion parameter
         (usually denoted \eqn{\theta} or \eqn{k}); in contrast to
         most other families, larger \eqn{\theta} corresponds to a \emph{lower}
         variance which is \eqn{\mu(1+\mu/\theta)}.}
     \item{Gamma}{Internally, glmmTMB fits Gamma responses by fitting a mean
         and a shape parameter; sigma is estimated as (1/sqrt(shape)),
         which will typically be close (but not identical to) that estimated
         by \code{stats:::sigma.default}, which uses sqrt(deviance/df.residual)}
     \item{beta}{returns the value of \eqn{\phi}, 
         where the conditional variance is \eqn{\mu(1-\mu)/(1+\phi)} 
         (i.e., increasing \eqn{\phi} decreases the variance.) 
         This parameterization follows Ferrari and Cribari-Neto (2004)
         (and the \code{betareg} package):}
     \item{betabinomial}{This family uses the same parameterization (governing
          the Beta distribution that underlies the binomial probabilities) as \code{beta}.}
     \item{genpois}{returns the value of \eqn{\phi},
          where the variance is \eqn{\mu\phi}}
     \item{compois}{returns the value of \eqn{1/\nu},
          When \eqn{\nu=1}, compois is equivalent to the Poisson distribution.
          There is no closed form equation for the variance, but 
          it is approximately undersidpersed when \eqn{1/\nu <1}
          and approximately oversidpersed when \eqn{1/\nu >1}.
          In this implementation, \eqn{\mu} is excatly the mean, which
          differs from the COMPoissonReg package (Sellers & Lotze 2015).}
}

 The most commonly used GLM families 
 (\code{binomial}, \code{poisson}) have fixed dispersion parameters which are 
 internally ignored.
}
\references{
\itemize{
\item Ferrari SLP, Cribari-Neto F (2004). "Beta Regression for Modelling Rates and Proportions." \emph{J. Appl. Stat.}  31(7), 799-815.
\item Hardin JW & Hilbe JM (2007). "Generalized linear models and extensions." Stata press.
\item Sellers K & Lotze T (2015). "COMPoissonReg: Conway-Maxwell Poisson (COM-Poisson) Regression". R package version 0.3.5. https://CRAN.R-project.org/package=COMPoissonReg
}
}
