
# author:  Norm Matloff

# smoothz() applies a kNN smoothing function to the given data set, for
# either density or regression estimation; in either case, the function
# is evaluated on the same points as it is estimated from

# smoothzpred() does regression prediction on new data

# arguments:
#    cls:  Snow cluster 
#    z:  data matrix/data frame, one observation per row; 
#       in regression case, last column is Y
#    sf:  smoothing function, knnreg() or knndens() 
#    checkna:  if True, eliminate any row in z with at least 1 NA
# return value:
#    values of the smoothing function for each observation in z 

# knnreg() and knndens() use k-nearest neighbor estimates, in order to
# take advantage of the fast (and already implemented) FNN package

smoothz <- function(z,sf,k,checkna=T,cls=NULL,
            nchunks=length(cls)) {
   require(parallel)
   if (is.vector(z)) z <- matrix(z,ncol=1)
   if (is.data.frame(z)) z <- as.matrix(z)
   if (checkna) z <- z[complete.cases(z),]
   if (is.null(cls)) {
      return(sf(z,k))
   } else {
      # determine which observations each node will process
      n <- nrow(z)
      idxchunks <- splitIndices(n,nchunks)
      zchunks <- Map(function(ichunk) z[ichunk,],idxchunks)
      tmp <- clusterApply(cls,zchunks,sf,k)
      return(Reduce(c,tmp))
   }
}

# kNN regression; predict the points in data from those points
knnreg <- function(data,k) {
   require(FNN)
   ycol <- ncol(data)
   x <- data[,-ycol,drop=F]
   y <- data[,ycol]
   idx <- get.knn(data=x,k=k)$nn.index
   # i-th row of idx contains the indices of the k nearest neighbors to
   # that row of x (not including that row)
   apply(idx,1,function(idxrow) mean(y[idxrow]))
}

# kNN density estimation
knndens <- function(data,k) {
   # finds kNN-based density estimates at the rows of data
   require(FNN)
   dsts <- get.knn(data,k=k)$nn.dist
   hvec <- dsts[,k]
   # (k/nrow(data)) / (pi * hvec^2)
   (k/nrow(data)) / (hvec^ncol(data))
}

# predicts Y values for the rows in newx, based on the X data oldx from
# our training set and the corresponding estimated regression values
# oldxregest; since the latter are already the result of smoothing, we
# predict via 1-NN 
smoothzpred <- function(newx,oldx,oldxregest,
      checkna=T,cls=NULL,nchunks=length(cls)) {
   require(parallel)
   if (is.vector(newx)) newx <- matrix(newx,nrow=1)
   if (is.vector(oldx)) oldx <- matrix(oldx,nrow=1)
   if (is.data.frame(newx)) newx <- as.matrix(newx)
   if (is.data.frame(oldx)) oldx <- as.matrix(oldx)
   if (checkna) newx <- newx[complete.cases(newx),]
   if (is.null(cls)) {
      return(onennreg(newx,oldx,oldxregest))
   } else {
      n <- nrow(newx)
      # determine which observations each node will process
      idxchunks <- splitIndices(n,nchunks)
      newxchunks <- Map(function(ichunk) newx[ichunk,],idxchunks)
      tmp <- clusterApply(cls,newxchunks,onennreg,oldx,oldxregest)
      return(Reduce(c,tmp))
   }
}

# 
onennreg <- function(nx,ox,oxrgest) {
   require(FNN)
   if (is.vector(nx)) nx <- matrix(nx,nrow=1)
   if (is.vector(ox)) ox <- matrix(ox,nrow=1)
   pred1row <- function(nxrow) {
      nxrow <- matrix(nxrow,nrow=1)
      idx <- get.knnx(data=ox,query=nxrow,k=1)$nn.index
      oxrgest[idx]
   }
   apply(nx,1,pred1row)
}
