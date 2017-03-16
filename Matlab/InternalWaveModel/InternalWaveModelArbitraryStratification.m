classdef InternalWaveModelArbitraryStratification < InternalWaveModel
    
    properties
       S
       Sprime
    end
    
    methods
        function self = InternalWaveModelArbitraryStratification(dims, n, rho, z, nModes, latitude)
            if length(dims) ~=3
                error('The dimensions must be given as [Lx Ly Lz] where Lz is the depth of the water column.');
            end
            if length(n) == 2
               n(3) = length(z); 
            end
            if length(n) ~=3
                error('The number of grid points must be given as [Nx Ny Nz] or [Nx Ny]).');
            elseif n(3) ~= length(z)
                error('Nz must equal length(z)');                
            end
            
            im = InternalModes(rho,[-dims(3) 0],z,latitude,'nEVP', 64);
            im.nModes = nModes;
            N2 = im.N2;
            
            self@InternalWaveModel(dims, n, z, N2, nModes, latitude);
            
            self.S = zeros(self.Nz, self.nModes, self.Nx, self.Ny);
            self.Sprime = zeros(self.Nz, self.nModes, self.Nx, self.Ny);
            
            K2 = self.K2(:,:,1);
            [K2_unique,~,iK2_unique] = unique(K2);
            fprintf('Solving the EVP for %d unique wavenumbers.\n',length(K2_unique));
            for iUnique=1:length(K2_unique)
                kk = K2_unique(iUnique);
                
                [F,G,h] = im.ModesAtWavenumber(sqrt(kk));
                h = reshape(h,[1 1 self.nModes]);
                
                indices = find(iK2_unique==iUnique);
                for iIndex=1:length(indices)
                    currentIndex = indices(iIndex);
                    [i,j] = ind2sub([self.Nx self.Ny], currentIndex);
                    self.h(i,j,:) = h;
                    self.S(:,:,i,j) = G;
                    self.Sprime(:,:,i,j) = F;
                end
            end
            
            self.SetOmegaFromEigendepths(h);
            
            % Slower algoritm
%             for i=1:self.Nx
%                 for j=1:self.Ny
%                     kk = self.K2(i,j,1);
%                                          
%                     [F,G,h] = im.ModesAtWavenumber(sqrt(kk));
%                     self.h(i,j,:) = reshape(h,[1 1 self.nModes]);
%                     self.S(:,:,i,j) = G;
%                     self.Sprime(:,:,i,j) = F;
%                 end
%             end
        end
        
        function [F,G,h] = ModesForConstantStratificationAtWavenumber(self, N0, k)
            kk = k*k;
            z = reshape(self.z,[self.Nz 1 1 1]);
            mode = reshape(1:self.nModes,[1 self.nModes 1 1]);
            kz = (pi/self.Lz)*mode;
            g = 9.81;
            
            h = (N0*N0-f0*f0)./(g*(kz.*kz + kk));
            G = sqrt(2*g/(self.Lz*(N0*N0-self.f0*self.f0)))*sin(kz.*z);
            F = sqrt(2*g/(self.Lz*(N0*N0-self.f0*self.f0)))* h.*kz.*cos(kz.*z);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Computes the phase information given the amplitudes (internal)
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function u = TransformToSpatialDomainWithF(self, u_bar)
            u_bar = permute(u_bar,[3 1 2]); % Speed optimization: keep matrices adjacent in memory
            
            u_temp = zeros(size(u_bar));
            for i=1:self.Nx
                for j=1:self.Ny
                    u_temp(i,j,:) = self.Sprime(:,:,i,j)*u_bar(:,i,j);
                end
            end
            
            % Here we use what I call the 'Fourier series' definition of the ifft, so
            % that the coefficients in frequency space have the same units in time.
            u = self.Nx*self.Ny*ifft(ifft(u_temp,self.Nx,1),self.Ny,2,'symmetric');
        end
        
        function w = TransformToSpatialDomainWithG(self, w_bar )
            w_bar = permute(w_bar,[3 1 2]); % Speed optimization: keep matrices adjacent in memory
            
            w_temp = zeros(size(w_bar));
            for i=1:self.Nx
                for j=1:self.Ny
                    w_temp(i,j,:) = self.S(:,:,i,j)*w_bar(:,i,j);
                end
            end
            
            % Here we use what I call the 'Fourier series' definition of the ifft, so
            % that the coefficients in frequency space have the same units in time.
            w = self.Nx*self.Ny*ifft(ifft(w_temp,self.Nx,1),self.Ny,2,'symmetric');
        end
    end
end