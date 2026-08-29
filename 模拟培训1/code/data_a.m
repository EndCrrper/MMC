function D = data_a(na,nz)
if nargin<1, na=24; end
if nargin<2, nz=5; end
D.g = 9.8;
D.vm = 300;
D.rs = 10;
D.vs = 3;
D.life = 20;
D.m0 = [20000 0 2000; 19000 600 2100; 18000 -600 1900];
D.u0 = [17800 0 1800; 12000 1400 1400; 6000 -3000 700; ...
        11000 2000 1800; 13000 -2000 1300];
D.T = vecnorm(D.m0, 2, 2) / D.vm;
D.tc = [0 200 5];

a = linspace(0,2*pi,na+1)';
a(end) = [];
z = linspace(0,10,nz)';
[aa, zz] = meshgrid(a, z);
D.side = [7*cos(aa(:)), 200+7*sin(aa(:)), zz(:)];
D.normal = [cos(aa(:)), sin(aa(:)), zeros(numel(aa),1)];

r = [0 3.5 7];
top = [0 200 10];
for k = 2:numel(r)
    top = [top; r(k)*cos(a), 200+r(k)*sin(a), 10*ones(numel(a),1)]; %#ok<AGROW>
end
D.top = top;
end
