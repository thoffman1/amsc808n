function Q1()
close all
% read data
A2012 = readmatrix('A2012.csv');
A2016 = readmatrix('A2016.csv');
% Format for A2012 and A2016:
% FIPS, County, #DEM, #GOP, then <str> up to Unemployment Rate
str = ["Median Income", "Migration Rate", "Birth Rate",...
"Death Rate", "Bachelor Rate", "Unemployment Rate","log(#Votes)"];

% remove column county that is read by matlab as NaN
A2012(:,2) = [];
A2016(:,2) = [];
A = A2016;
% remove all rows with missing data
A(~isfinite(A(:,2)) |  ~isfinite(A(:,3)) | ~isfinite(A(:,4)) ...
    | ~isfinite(A(:,5)) | ~isfinite(A(:,6)) | ~isfinite(A(:,7)) ...
    | ~isfinite(A(:,8)) | ~isfinite(A(:,9)),:) = [];
% select CA, OR, WA, NJ, NY counties
ind = find((A(:,1)>=6000 & A(:,1)<=6999) ...  %CA
 | (A(:,1)>=53000 & A(:,1)<=53999) ...        %WA
 | (A(:,1)>=34000 & A(:,1)<=34999));% ...        %NJ  
%  | (A(:,1)>=36000 & A(:,1)<=36999) ...        %NY
%  | (A(:,1)>=41000 & A(:,1)<=41999));          %OR
A = A(ind,:);

[n,dim] = size(A);

% assign labels: -1 = dem, 1 = GOP
idem = find(A(:,2) >= A(:,3));
igop = find(A(:,2) < A(:,3));
num = A(:,2)+A(:,3);
label = zeros(n,1);
label(idem) = -1;
label(igop) = 1;

% select max subset of data with equal numbers of dem and gop counties
ngop = length(igop);
ndem = length(idem);
if ngop > ndem
    rgop = randperm(ngop,ndem);
    Adem = A(idem,:);
    Agop = A(igop(rgop),:);
    A = [Adem;Agop];
else
    rdem = randperm(ndem,ngop);
    Agop = A(igop,:);
    Adem = A(idem(rdem),:);
    A = [Adem;Agop];
end  
[n,dim] = size(A);
idem = find(A(:,2) >= A(:,3));
igop = find(A(:,2) < A(:,3));
num = A(:,2)+A(:,3);
label = zeros(n,1);
label(idem) = -1;
label(igop) = 1;

% set up data matrix and visualize original data
X = [A(:,4:9),log(num)];
X(:,1) = X(:,1)/1e4;
% select three data types that distinguish dem and gop counties the most
i1 = 1; % Median Income
i2 = 5; % Bachelor Rate
i3 = 6; % Unemployment Rate
ixx = [i1, i2, i3];
% visualize([], X, idem, igop, str(ixx), 'Original Data');

% rescale data to [0,1]
XX = X(:,ixx); % data matrix
xmin = min(XX(:,1)); xmax = max(XX(:,1));
ymin = min(XX(:,2)); ymax = max(XX(:,2));
zmin = min(XX(:,3)); zmax = max(XX(:,3));
X1 = (XX(:,1)-xmin)/(xmax-xmin);
X2 = (XX(:,2)-ymin)/(ymax-ymin);
X3 = (XX(:,3)-zmin)/(zmax-zmin);
XX = [X1,X2,X3];

% set up optimization problem
[n,dim] = size(XX);
lam = 0.01;
Y = (label*ones(1,dim + 1)).*[XX,ones(n,1)];
w0 = [-1;-1;1;1];
fun = @(I,Y,w)fun0(I,Y,w,lam);
gfun = @(I,Y,w)gfun0(I,Y,w,lam);
Hvec = @(I,Y,w,v)Hvec0(I,Y,w,v,lam);

bulksz = 10;   %number of simulations to run before averaging

% Set up and solve SVN problem with soft margins with ASM
A = [Y, eye(n); zeros(n, dim+1), eye(n)];
b = [ones(n,1); zeros(n,1)];
C = 10^3;

% Get initial guess with SINewton
[w0, ~, ~] = SINewton(fun,gfun,Hvec,Y,w0,-1);
xi0 = max(ones(n,1) - Y*w0, 0); % initial guess for xi with ReLU
w0 = [w0; xi0];

% Solve by minimizing a ReLU loss function (VERY BAD!!!)
% xi0 = max(ones(n,1) - Y*w0, 0); % initial guess for xi with ReLU
% [wSVN, ~, ~] = FindInitGuess([w0; xi0], A, b);

% Set up gradient and Hessian functions for the problem
gfun = @(x) [eye(dim) zeros(dim, n+1); zeros(n+1, dim) zeros(n+1, n+1)]*x ...
    + C*[zeros(dim+1,1); ones(n,1)];
Hfun = @(x) [eye(dim), zeros(dim, n+1); zeros(n+1, dim), zeros(n+1, n+1)];

gnorms = zeros(bulksz,5000);
for i = 1:bulksz
    t0 = tic;
    [xiter, lm, gnorm] = ASM(w0, gfun, Hfun, A, b, []); % compute
    tf = toc(t0);
    wSVN = xiter(1:4);
    gnorms(i,:) = gnorm;
end
visualize(wSVN, XX, idem, igop, str(ixx), 'Soft Margins SVN');

% Average gnorms
avged = mean(gnorms);

figure; grid on
loglog(0:length(avged)-1, avged, 'k', 'LineWidth', 1.75);
xlabel('iteration number');
ylabel('norm of gradient');
title(['Performance test, runtime = ' num2str(tf) 's']);
end

function fig = visualize(w, XX, idem, igop, labs, varargin)
if nargin > 2
    titlestr = varargin{1};
end
% get bbox values
xmin = min(XX(:,1)); xmax = max(XX(:,1));
ymin = min(XX(:,2)); ymax = max(XX(:,2));
zmin = min(XX(:,3)); zmax = max(XX(:,3));

fig = figure;
hold on; grid on;
plot3(XX(idem,1),XX(idem,2),XX(idem,3),'.','color','b','Markersize',20);
plot3(XX(igop,1),XX(igop,2),XX(igop,3),'.','color','r','Markersize',20);
view(3)
fsz = 16;
set(gca,'Fontsize',fsz);
xlabel(labs(1),'Fontsize',fsz);
ylabel(labs(2),'Fontsize',fsz);
zlabel(labs(3),'Fontsize',fsz);
title(titlestr);

if ~isempty(w)
    nn = 50;
    [xx,yy,zz] = meshgrid(linspace(xmin,xmax,nn),linspace(ymin,ymax,nn),...
        linspace(zmin,zmax,nn));
    plane = w(1)*xx+w(2)*yy+w(3)*zz+w(4);
    p = patch(isosurface(xx,yy,zz,plane,0));
    p.FaceColor = 'green';
    p.EdgeColor = 'none';
    camlight 
    lighting gouraud
    alpha(0.3);
end
end

function f = fun0(I,Y,w,lam)
f = sum(log(1 + exp(-Y(I,:)*w)))/length(I) + 0.5*lam*w'*w;
end

function g = gfun0(I,Y,w,lam)
aux = exp(-Y(I,:)*w);
d1 = size(Y,2);
g = sum(-Y(I,:).*((aux./(1 + aux))*ones(1,d1)),1)'/length(I) + lam*w;
end

function Hv = Hvec0(I,Y,w,v,lam)
aux = exp(-Y(I,:)*w);
d1 = size(Y,2);
Hv = sum(Y(I,:).*((aux.*(Y(I,:)*v)./((1+aux).^2)).*ones(1,d1)),1)' + lam*v;
end

function [w,l,lcomp] = FindInitGuess(w,A,b)
    relu = @(w) max(w,0);
    drelu = @(w) ones(size(w)).*sign(relu(w));
    l = sum(relu(b - A*w));
    iter = 0;
    itermax = 10000;
    step = 0.1;
    while l > 0 && iter < itermax
        dl = sum(-drelu(b - A*w)'*A, 1)';
        if norm(dl) > 1
            dl = dl/norm(dl);
        end
        w = w - step*dl;
        l = sum(relu(b - A*w));
        iter = iter + 1;
    end
%     fprintf('%d iterations: x = [%d,%d],f = %d\n',iter, w(1),w(2),l);
    lcomp = relu(b - A*w);
end