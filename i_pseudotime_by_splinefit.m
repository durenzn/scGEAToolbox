function [t,xyz1]=i_pseudotime_by_splinefit(xyz,dim,plotit)
% s_selected=s_phate0g1(cell_i,:);
if nargin<3
    plotit=false;
end
if nargin<2
    dim=1;
end

if size(xyz,2)==3
    x=xyz(:,1);
    y=xyz(:,2);
    z=xyz(:,3);
elseif size(xyz,2)==2
    x=xyz(:,1);
    y=xyz(:,2);
    z=ones(size(x));   
end

switch dim
    case 1
        [~,i]=max(x);
    case 2
        [~,i]=max(y);        
    case 3
        [~,i]=max(z);        
end


[~,j]=sort(pdist2(xyz,xyz(i,:)));
xyz=xyz(j,:)';

x=x(j);
y=y(j);
z=z(j);

s = cumsum([0;sqrt(diff(x(:)).^2 + diff(y(:)).^2 + diff(z(:)).^2)]);
pp1 = splinefit(s,xyz,15,0.75);
xyz1 = ppval(pp1,s);

% D=pdist2(xyz',xyz1');
% [~,t]=min(D,[],2);

% t=sqrt(sum(xyz1.^2-xyz1(:,1).^2));
% t=sqrt(sum((xyz1-xyz1(:,1)).^2));
t=pdist2(xyz1',xyz1(:,1)')';
[~, j_rev] = sort(j); 
t = t(j_rev);

xyz1 = xyz1';
if size(xyz,2)==2
    xyz1=xyz1(:,1:2);
end

% https://www.mathworks.com/matlabcentral/fileexchange/47042-pathdist

% s=run_phate(X,3,false,true);
% [t,xyz1]=i_pseudotime_by_splinefit(s,1);
if plotit
 hold on
 plot3(xyz1(:,1),xyz1(:,2),xyz1(:,3),'-r','linewidth',2);
end
end


