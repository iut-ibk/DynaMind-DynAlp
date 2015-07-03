########################################################
# swmmrptreader.R
########################################################
rm(list=ls())
library("tools")
# options(error=traceback)
########################################################

wrkpath <- ("~/Work/Current/reportreader")
reppath <- (file.path(wrkpath,"repfiles"))
outpath <- (file.path(wrkpath,"output"))

NODES <- 1 # node detail reports
#JUNCTION <- 0
#SUBCATCHMENT <- 0
wwtp <- c("V020","ARA1") # wwtps are handled differently

#######################################################
crosstotal<-function(tab,sectiontable,valcol)
{
    for(k in 1:dim(sectiontable)[1])
    {
        value <- as.numeric(sectiontable[k,valcol])
        if (!value > 0) next
        
        nodename <- sectiontable[k,1]
        ni<-which(tab[,1]==nodename)
        
        if(length(ni))
        {
            ni<-which(tab[,1]==nodename)
            tab[ni,2] = as.numeric(tab[ni,2])+value
            tab[ni,3] = as.numeric(tab[ni,3])+1
        }
        else
        {
            values <-c(nodename,value,1)
            tab <- rbind(tab,values)
        }
    }
    return(tab)
}

repfiles <- Sys.glob(file.path(reppath,"*.rep"))

summarymatrixnames=c("name","numberSubcatchments","SUMtotRunoff[Ml]","nInflowNodes","SUMmaxtotInflow[lps]","SUMtotInflowVolume[Ml]","nSurchargedNodes","surcharged[h]","nFloodingNodes","Sumhoursflooded","SUMtotFloodVolume[Ml]","numberStorages","SUMaverageVol[Ml]","SUMmaxVol[Ml]","SUMmaxPcnt","nOutfalls","SUMtotOutfallVolume[Ml]","SUMtotWWTPVolume[Ml]","NSurchargeConduits","SUMhourslimitedcapacity","nPumps","SUMtotPumpVolume[Ml]")

summarymatrix<-matrix(nrow=length(repfiles),ncol=length(summarymatrixnames))
colnames(summarymatrix) <- summarymatrixnames

floodingsummary<-matrix(nrow=0,ncol=3)
outfallsummary<-matrix(nrow=0,ncol=3)

for(filenr in 1:length(repfiles))
{
    print(repfiles[filenr])
	summarymatrix[filenr,1] <- basename(file_path_sans_ext(repfiles[filenr]))

	rep <- read.table(repfiles[filenr],sep="\t")
	
	emptylines <- which(nchar(gsub("\\s+","",rep[,1]))==0)
	breaklines <- grep("-----------------------",as.character(rep[,1]))
	nodelines <- grep("<<<",rep[,1])
	
	S<-list()
	S[["Subcatchment Runoff Summary"]]<-c("Subcatchment","totPrec","totRunon","totEvap","totInfil","totRunoff","totRunoff2","PeakRunoff","RunoffCoeff")
	S[["Node Depth Summary"]]<-c("Node","Type","AvgD","MaxD","MaxHGL","tMaxOcc_d","t_MaxOcc_HrMin")
	S[["Node Inflow Summary"]]<-c("Node","Type","MaxLatInflow","MaxTotInflow","tMaxOcc_d","t_MaxOcc_HrMin","LatInflowVol","TotInflowVol","FlowBalErr")
	S[["Node Surcharge Summary"]]<-c("Node","Type","hSurch","MaxHabCrown","MinDbelRim")
	S[["Node Flooding Summary"]]<-c("Node","hFlooded","MaxRate","tMaxOcc_d","t_MaxOcc_HrMin","TotFloodV","MaxPondD")
	S[["Storage Volume Summary"]]<-c("StorUnit","AvgVol","AvgPcntFull","EvapPcntLoss","ExfilPcntLoss","MaxVol","MaxPcntFull","tMaxOcc_d","t_MaxOcc_HrMin","MaxOutflow")
	S[["Outfall Loading Summary"]]<-c("OutfallNode","FlowFreqPcnt","AvgFlow","MaxFlow","TotVol")
	S[["Link Flow Summary"]]<-c("Link","Type","MaxFlow","tMaxOcc_d","t_MaxOcc_HrMin","MaxVeloc","MaxFullFlow","MaxFullDepth")
	S[["Flow Classification Summary"]]<-c("Conduit","AdjActL","F_Dry","F_UpDry","F_DownDry","F_SubCrit","F_SupCrit","F_UpCrit","F_DownCrit","F_NormLtd","F_InletCtrl")
	S[["Conduit Surcharge Summary"]]<-c("Conduit","HF_BothEnds","HF_Upstream","HF_Dnstream","HabFullNormF","HCapLim")
	S[["Pumping Summary"]]<-c("Pump","PctUt","NStartups","MinFlow","AvgFlow","MaxFlow","TotVol","PowerUsage","PctTimeOff_PumpLow","PctTimeOff_CurveHigh")
	S[["Node Results"]]<-c("Date","Time","Inflow[lps]","Flooding[lps]","Depth[m]","Head[m]")
	S[["Conduit Results"]]<-c("Date","Time")
	
	currentdir <- file.path(outpath,basename(file_path_sans_ext(repfiles[filenr])))
	dir.create(currentdir)
	
	for (section in names(S))
	{
	    if ( length(grep(section,rep[,1])) )
	        {
	        if ( section == "Node Results" )
	        {
	            S[["Node Depth Summary"]]<-c("Node","Type","AvgD","MaxD","MaxHGL","tMaxOcc_d","t_MaxOcc_HrMin","MaxrepD")
	            nodedir <- file.path(currentdir,"NODES")
	            dir.create(nodedir)
	        }
	    }
	    else
	    {
	        S[c(section)] <- NULL
	    }
	}
	
	for (section in names(S))
	{
	    sectionstart<-grep(section,rep[,1])
	    start<-breaklines[breaklines>sectionstart][2]+1
	    end<-emptylines[emptylines>start][1]-1
	
		if (section == "Outfall Loading Summary")
		{
			end<-emptylines[emptylines>start][1]-3
		}
	    
        data<-rep[start:end,] # get section
        data<-gsub("(^[[:space:]]+|[[:space:]]+$)", "", data) #trim leading and trailing spaces
        data<-strsplit(as.character(data),"\\s+") #split data

        sectiontable<-matrix(nrow=length(data),ncol=length(data[[1]]))

	    for (j in 1:length(data)) { sectiontable[j,]<-data[[j]][1:ncol(sectiontable)] }
        sectiontable[is.na(sectiontable)] <- 0
    
    # the following section will be split by types
	    if (section == "Node Depth Summary" ||
	        section == "Node Inflow Summary" ||
	        section == "Node Surcharge Summary"||
	        section == "Link Flow Summary")
	    {
	        types<-vector(length=dim(sectiontable)[1])
			
		    for (j in 1:dim(sectiontable)[1]) { types[j]<-sectiontable[j,2] }
      
		    ctypes<-row.names(table(types))
		    ntypes<-table(types)
			
		    for(typenr in 1:length(ctypes))
		    {
			    typestart <- min(which(types == ctypes[typenr]))
			    typeend <- typestart+ntypes[[typenr]]-1
			    typedata <- strsplit(as.character(data[typestart:typeend]),"\\s+")
        
			    typetable <- matrix(nrow=length(typedata),ncol=length(typedata[[1]]))
			    for(j in 1:dim(typetable)[1]) {	typetable[j,]<-typedata[[j]][1:ncol(typetable)] }
				
				if (ctypes[typenr] == "PUMP") { colnames(typetable) <- S[[section]][-c(6,8)] }
                else if (ctypes[typenr] == "ORIFICE" ) { colnames(typetable) <- S[[section]][-c(6,7)] }
				else if (ctypes[typenr] == "WEIR" ) { colnames(typetable) <- S[[section]][-c(6,7)] }
				else { colnames(typetable) <- S[[section]] }
		    }
		    filename<-file.path(currentdir,paste(gsub("\\s","\\_",section),".csv",sep=""))
		    write.csv2(typetable,filename,row.names=F)
	    }
		
		else if (section == "Node Results")
		{
			for (nodenr in 1:length(nodelines))
			{
				start <- nodelines[nodenr]
				nodename <- gsub("\\s+<<< Node\\s+","",rep[start,])
				nodename <- gsub("\\s+>>>\\s*","",nodename)
				nodename <- gsub("[[:punct:]]","_",nodename)
				start <- start + 5
				end <- emptylines[emptylines>start][1] - 1
           
	            nodedata <- rep[start:end,]
	            nodedata<-gsub("(^[[:space:]]+|[[:space:]]+$)", "", nodedata) #trim leading and trailing spaces
	            nodedata<-strsplit(as.character(nodedata),"\\s+")
	            nodetable<-matrix(nrow=length(nodedata),ncol=length(nodedata[[1]]))
	            
	            for(j in 1:dim(nodetable)[1]) {	nodetable[j,]<-nodedata[[j]][1:ncol(nodetable)] }
	            colnames(nodetable)=S[[section]]
	            
	            filename<-file.path(nodedir,paste(nodename,".csv",sep=""))
            
	            write.csv2(nodetable,filename,row.names=F)
	        }
		}
	    else
	    {
	        colnames(sectiontable) <- S[[section]]
	        
	        filename<-file.path(currentdir,paste(gsub("\\s","\\_",section),".csv",sep=""))
	        write.csv2(sectiontable,filename,row.names=F)
	    }
        
        ## Summarys handled below
        
	    if (section == "Subcatchment Runoff Summary")
	    {
	        summarymatrix[filenr,2]<-dim(sectiontable)[1] #numberSubcatchments
	        summarymatrix[filenr,3]<-sum(as.numeric(sectiontable[,6])) #SUMtotRunoff[Ml]
	    }
        else if (section == "Node Inflow Summary")
        {
            summarymatrix[filenr,4]<-dim(sectiontable)[1] #numberInflowNodes
            summarymatrix[filenr,5]<-sum(as.numeric(sectiontable[,4])) #SUMmaxtotInflow[lps]
            summarymatrix[filenr,6]<-sum(as.numeric(sectiontable[,8])) #SUMtotInflowVolume[Ml]
        }
        else if (section == "Node Surcharge Summary")
        {
            summarymatrix[filenr,7]<-dim(sectiontable)[1] #numberSurchargeNodes
            summarymatrix[filenr,8]<-sum(as.numeric(sectiontable[,3])) #hourssurcharged
        }
        else if (section == "Node Flooding Summary") # Count of Surcharge nodes through all Simulations
        {
            summarymatrix[filenr,9]<-dim(sectiontable)[1] #numberFloodingNodes
            summarymatrix[filenr,10]<-sum(as.numeric(sectiontable[,2])) #SUMhoursflooded
            summarymatrix[filenr,11]<-sum(as.numeric(sectiontable[,6])) #SUMFloodVolume
            floodingsummary<-crosstotal(floodingsummary,sectiontable,6)
        }
        else if (section == "Storage Volume Summary")
        {
            summarymatrix[filenr,12]<-dim(sectiontable)[1] #numberStorages
            summarymatrix[filenr,13]<-sum(as.numeric(sectiontable[,2])) #SUMaverageVol[Ml]
            summarymatrix[filenr,14]<-sum(as.numeric(sectiontable[,6])) #SUMmaxVol[Ml]
            summarymatrix[filenr,15]<-sum(as.numeric(sectiontable[,7])) #SUMmaxPcnt
        }
        else if (section == "Outfall Loading Summary") # Count of Outfall events per node through all Simulations
        {
            summarymatrix[filenr,16]<-(dim(sectiontable)[1] - length(wwtp)) #noutfalls
            summarymatrix[filenr,17]<-sum(as.numeric(sectiontable[which(!(sectiontable[,1] %in% wwtp)),5])) #SUMtotOutfallVolume[Ml] without WWTP
            summarymatrix[filenr,18]<-sum(as.numeric(sectiontable[which((sectiontable[,1] %in% wwtp)),5])) #SUMtotWWTPVolume[Ml]
            outfallsummary<-crosstotal(outfallsummary,sectiontable,5)
        }
        else if (section == "Conduit Surcharge Summary")
        {
            summarymatrix[filenr,19]<-dim(sectiontable)[1] #NSurchargeConduits
            summarymatrix[filenr,20]<-sum(as.numeric(sectiontable[,6])) #SUMhourslimitedcapacity
        }
        else if (section == "Pumping Summary")
        {
            summarymatrix[filenr,21]<-dim(sectiontable)[1] #nPumps
            summarymatrix[filenr,22]<-sum(as.numeric(sectiontable[,7])) #SUMtotPumpVolume[Ml]
        }
	}
}

write.csv2(summarymatrix,file.path(outpath, "summary.csv"),row.names=T)

colnames(floodingsummary)=c("Node","sumFloodingVol","nOcc")
write.csv2(floodingsummary,file.path(outpath, "floodingsummary.csv"),row.names=F)

colnames(outfallsummary)=c("OutfallNode","sumTotVol","n_Outfalls")
write.csv2(outfallsummary,file.path(outpath, "outfallsummary.csv"),row.names=F)

# print(warnings())