Lx = 30e3;
Ly = 30e3;
Lz = 5000;

Nx = 256;
Ny = 256;
Nz = 257;

Nx = 64;
Ny = 64;
Nz = 65;

Nx = 128;
Ny = 128;
Nz = 129;

latitude = 31;
N0 = 5.2e-3/2;
t = 12*3600; 1*86400;

wavemodel = InternalWaveModelConstantStratification([Lx, Ly, Lz], [Nx, Ny, Nz], latitude, N0);

Lh = Lx/32;
Lv = Lz/8;
x0 = Lx/2;
y0 = Ly/2;
z0 = -Lz/2;

X = wavemodel.X;
Y = wavemodel.Y;
Z = wavemodel.Z;

% zeta0 = 100*exp( -((X-x0).^2 + (Y-y0).^2)/(Lh)^2  - ((Z-z0).^2)/(Lv)^2 );
% zeta0 = 100*exp( -((X-x0).^2 + (Y-y0).^2)/(Lh)^2  - ((Z-z0).^2)/(Lv)^2 ).*sin(X/(Lh/4));
zeta0 = 100*exp( -((X-x0).^2 + (Y-y0).^2)/(Lh)^2  - ((Z-z0).^2)/(Lv)^2 ).*sin(X/(Lh/8)+Z/(Lv/6));


wavemodel.InitializeWithIsopycnalDisplacementField(zeta0);

[u, v, w, rho_prime, zeta]= wavemodel.VariableFieldsAtTime(0*3600, 'u', 'v', 'w', 'rho_prime', 'zeta');

maxU = max(max(max(abs(u))));
maxV = max(max(max(abs(v))));
maxW = max(max(max(abs(w))));
fprintf('Maximum fluid velocity (u,v,w)=(%.2f,%.2f,%.2f) cm/s\n',100*maxU,100*maxV,100*maxW);

dispvar = zeta;
figure
subplot(2,1,1)
pcolor(wavemodel.x,wavemodel.z,squeeze(dispvar(:,Ny/2,:))'),shading flat
subplot(2,1,2)
pcolor(wavemodel.x,wavemodel.y,squeeze(dispvar(:,:,floor(Nz/2)))'),shading flat
figure
plot(wavemodel.x,squeeze(dispvar(:,Ny/2,floor(Nz/2))));