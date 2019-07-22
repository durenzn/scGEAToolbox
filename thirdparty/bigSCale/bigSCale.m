% function bigSCale()
% bigSCale ************************************************************************
% MAIN PIPELINE FOR CELL CLUSTERING AND MARKERS EXTRACTION WITH bigSCale
% GIOVANNI IACONO, CNAG, 16/08/2017

% ************************************************************************
% PARAMETERS FOR CLUSTERING AND MARKERS IDENTIFICATION

% regulates the speed of the hiererchical markers calculation.
% Fast,normal,slow. "Fast" preset ha lower accuracy, "slow" has higher
% accuracy.
speed_preset='fast';

% for selection of overdispersed genes
min_driving=4;
min_coreg=5;

% threshold for selection of DE genes, lower if not enough hiererchical
% markers are found. It is a Z-score, so it can be lowered down to 2 and
% remain significant.
markers_treshold=6;

% Depth at which Dendrogram is cut, the lower the number the higher the cluster numbers
Depth=0.20;

%************************************************************************
warning off all
if exist('SC_DE_MEX_double.mexw64')
    disp('SC_DE_MEX_double.mexw64 already compiled');
else
    disp('Compiling MEX code, BEWARE this step has not been tested yet on Linux or MacOs !!');
    mex SC_DE_MEX_double.c
end

if exist('SC_dist_MEX.mexw64')
    disp('SC_dist_MEX.mexw64 already compiled');
else
    disp('Compiling MEX code, BEWARE this step has not been tested yet on Linux or MacOs !!');
    mex SC_dist_MEX.c
end

if exist('SC_dist_MEX_double.mexw64')
    disp('SC_dist_MEX_double.mexw64 already compiled');
else
    disp('Compiling MEX code, BEWARE this step has not been tested yet on Linux or MacOs !!');
    mex SC_dist_MEX_double.c
end
%************************************************************************

resuming=0;
if exist('./results/temp.mat', 'file') == 2
    resuming=1;
    load('./results/temp.mat')
    new_depth=input('Resuming analysis: to what depth do you want to cut the dendogram (0-1)?  ')
else
    
% INITIATE THE VARIABLE EDGES
data_type=input('Are you working with 1)reads or 2) UMIs. Please enter number, 1 for reads, 2 for UMIs:   ');
load edges.mat
if data_type==1
    disp('Using data stucture for reads ...');
    edges=edgesUMIlarge;
else
    disp('Using data stucture for UMIs ...');
    edges=edgesUMI;
end
clear edgesUMI edgesUMIlarge


%%
% *********************************************************************
% Creation of iCells
% *********************************************************************
file='./input/expression.h5';
if exist(file, 'file') == 2
    
    disp('Detected a file with .h5 extension as input, proceeding to iCell calculation')
    indices = h5read(file,'/mm10/indices');
    indices=uint16(indices);
    indptr = h5read(file,'/mm10/indptr');
    data = h5read(file,'/mm10/data');
    data=uint16(data);
    %gene_names = h5read(file,'/mm10/gene_names');
    disp('IMPORTED BIG DATASET, PROCEESING TO iCELLs GENERATION')


    [N N_pct difference] = SC_new_algorithm_bigdata_v2( indices, indptr, data , edges);
    surf(N_pct)
    saveas(gcf,'./results/Numerical_model.png')
    close all
    [  somma_ex ] = SC_bigdata_somma_ex( indices, indptr, data );
    [driving_genes]= population_calling_bigdata( indices, indptr, data,0,min_driving,min_coreg);
    [ total_data ] = SC_bigdata_reduce( indices, indptr, data , driving_genes );
    [distances cells max_factor] = SC_bigdata_ds( total_data, N_pct , edges,somma_ex);
    %save('temp.mat','indices', 'indptr', 'data');
    clearvars -except cells distances max_factor
    SC_bigdata_collapse
    clearvars -except blocks
    dlmwrite('./results/iCells.txt',blocks);
    save('temp.mat');
    return;

end
% *********************************************************************


    
    % IMPORTING EXPRESSION COUNTS
    data_properly_imported=0;
    if exist('./input/expression.txt', 'file') == 2
        disp('Reading expression matrix')
        total_data=importdata('./input/expression.txt');
        data_properly_imported=1;
        data_format='small';
    end

    if exist('./input/indices.txt', 'file') == 2
        data_properly_imported=1;
        data_format='big';
    end

    if data_properly_imported==0
        error('The file(s) with the expression data must be in this folder and must be named correctly. Check youtube guide for help. ');
    end

    % IMPORTING GENE NAMES, IDS AND DESCRIPTIONS.
    if exist('./input/gene_names.txt', 'file') == 2
        disp('Reading gene names and info')
        [A]=importdata('./input/gene_names.txt');
        desrc_gene_names=strsplit(A{1},',')
        num_el=length(desrc_gene_names);
        if num_el>1
            for k=2:length(A)
                dummy=strsplit(A{k},',');
                dummy{num_el}=cell2mat(dummy(num_el:end));
                kg_or_ens(k,:)=dummy(1:num_el);
            end
        else
            kg_or_ens=A(2:end);
        end
        clear A
    else
        error('The file with the gene names  must be in this folder and must be named gene_names.txt. Check youtube guide for help. ');
    end

    % IMPORTING INFO FOR BATCHES, IF EXISTING
    if exist('./input/batches.txt', 'file') == 2
        disp('Reading batches, if present, to be used to remove batch effects')
        [A]=importdata('./input/batches.txt');
        batch_numbers=A.data;
        clear A
        tot_batches=max(batch_numbers);
        for k=1:tot_batches
            idx_pools{k}=find(batch_numbers==k);
        end
        [A]=importdata('./input/conditions.txt');
        conditions=A.data;
        clear A
        tot_conditions=max(conditions);
        for k=1:tot_conditions
            idx_samples{k}=find(conditions==k);
        end    
    else
        disp('There is no batch info file (cannot open ./input/batches.txt). Batch effect removal will not be applied.');
        idx_pools=[];
        idx_samples=[];
    end


    % OPTIONAL, remove batch effects
    if length(idx_pools) & isequal(data_format,'small')
        total_data=SC_remove_batches( total_data,idx_samples, idx_pools);
        dlmwrite('./results/total_data_batch_corrected.txt',total_data);
    end

    % CALCULATE THE MODEL
    disp('Calculating the numerical model of the noise.')
    if isequal(data_format,'small')
        [~, N_pct] = SC_new_algorithm( total_data , edges, 0);
    else
        [~, N_pct ] = SC_new_algorithm_bigdata_v2( indices, indptr, data , edges)
    end
    surf(N_pct)
    saveas(gcf,'./results/Numerical_model.png')
    close all



    % CALCULATE OVERDISPERSED GENES
    disp('Calculating overdispersed genes');

    % % option 1: calculate simply overdispersed genes
    % if isequal(data_format,'small')
    % 	[driving_genes, ~ ,score]= population_calling_v2( total_data, 0,min_driving,min_coreg);
    % else
    %     [driving_genes, ~ ,score]=population_calling_bigdata( indices, indptr, data, 0,min_driving,min_coreg);
    % end

    % option 2: returns only the overdispersed genes displaying a sufficent number of correlated genes
    if isequal(data_format,'small')
        [driving_genes, genes_related]= population_calling_v2( total_data,1,min_driving,min_coreg);
    else
        [driving_genes, genes_related]= population_calling_bigdata( indices, indptr, data, 1,min_driving,min_coreg);
    end




    % CALCULATE THE DISTANCE MATRIX OVER THE OVERDISPERSED GENES
    disp('Calculating Distance matrix');
    close all
    if isequal(data_format,'small')
    [ D_ls_mex ]=SC_1vs1_MEX( total_data(driving_genes,:), N_pct , edges,sum(total_data),[]);
    else
        % DOWNSAMPLING
        return;
    end
    close all

end

% Pit-stop
save('./results/temp.mat');
if resuming
    Depth=new_depth;
end

% CALCULATE THE DENDROGRAM AND THE CLUSTERS
Z = linkage(D_ls_mex,'ward'); 
[~,~,outperm]=dendrogram(Z,Inf,'ColorThreshold', Depth*max(Z(:,3)));
T = cluster(Z,'cutoff',Depth*max(Z(:,3)),'criterion','distance');
saveas(gcf,'./results/Final_clustering.png')
indices={};
names={};
count=1;
for k=1:max(T)
    if (nnz(T==k)>10)
        indices{count}=find(T==k);
        names{count}=sprintf('Cluster_%g',count);
        count=count+1;
    end
end
ix =  SC_info_dendro( outperm,indices );
indices=indices(ix);
clear ix k count ans
close all
for k=1:length(indices)
    T(indices{k})=k;
end
    
dlmwrite('./results/clustering.txt',T);
dlmwrite('./results/dendro_order.txt',outperm);



% CALCULATE AND WRITES TO DISK THE MARKERS OF LV.1  AND LV.2
disp('Calculating Markers');
[~ , ~ , ~ , ~ , I_scores]= SC_calculate_markers( total_data, indices, N_pct, markers_treshold , edges, speed_preset );

save('./results/final.mat');

% CALCULATES AND WRITES TO DISK THE COMPETE STRUCTURE OF HIERARCHICAL  MARKERS
disp('Exporting Markers');
all_markers=SC_bool_v2( I_scores , kg_or_ens, markers_treshold,'active');

disp('Terminated, you can browse the results in the ./results folder');

% end
% ***************************************************************************************************************************************************




