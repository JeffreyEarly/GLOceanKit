n = 1000;

lat = 33;
N0 = 5.2e-3; % reference buoyancy frequency, radians/seconds
g = 9.81;
rho_0 = 1025;
zIn = [-5000 0];
z = linspace(zIn(1),0,n)';

rho = @(z) -(N0*N0*rho_0/g)*z + rho_0;
N2 = @(z) N0*N0*ones(size(z));

im = InternalModesConstantStratification( rho, zIn, z, lat );

k = 10.^linspace(log10(1e-5),log10(1e-1),10);
psi = im.SurfaceModesAtWavenumber( k );

figure, plot(squeeze(psi),z)