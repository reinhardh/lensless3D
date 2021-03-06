f = 7.5; %Focal length of each lenslet
cpx = .0065; %Camera pixel size in microns
sensor_pix = [1000 1200];
sensor_size = [2048*cpx 2560*cpx];  %mm
mask_pix = [600 800];
mask_size = mask_pix*cpx; %mm
upsample = 3;   %how much to upsample for propagation
subsiz = upsample*mask_pix;  %Size of CA in pixels
px = mask_size(1)/subsiz(1);

nlenslets = 1000;
lens_centers = randsample(subsiz(1)*subsiz(2),nlenslets);
[rows,cols] = ind2sub(subsiz,lens_centers);
index = 1.51;
index_prime = 1;
dn = index_prime-index;
R = f*dn;
%Sphere: z = sqrt(1-(x-x0)^2/R^2 + (y-y0)^2/R^2)
suby = linspace(-floor(subsiz(1)/2)*px,floor(subsiz(1)/2)*px,subsiz(1));
subx = linspace(-floor(subsiz(2)/2)*px,floor(subsiz(2)/2)*px,subsiz(2));
[X, Y] = meshgrid(subx,suby);
x0 = ([rows, cols] - floor(subsiz/2))*px;
sph = @(x0,y0,R)sqrt(R^2-(X-x0).^2 - (Y-y0).^2);

%%
lenslet_surface = zeros(subsiz);
for n = 1:length(lens_centers)
    zt = sph(x0(n,2),x0(n,1),R);
    lenslet_surface = max(real(zt),lenslet_surface);
    
    if mod(n,10)==0
    imagesc(lenslet_surface)
    hold on
    scatter(cols(n),rows(n),'k+')
    hold off
    colormap parula
    axis image
    drawnow
    end
end

%%
lambda = 550e-6;
Ui = exp(-1i*2*pi*dn/lambda * lenslet_surface);
prepad = 
Ui = padarray(Ui,subsiz,'both');
siz = size(Ui);
y = linspace(-floor(siz(1)/2)*px,floor(siz(1)/2)*px,siz(1));
x = linspace(-floor(siz(2)/2)*px,floor(siz(2)/2)*px,siz(2));
[X,Y] = meshgrid(x,y);
fx = linspace(-1/2/px,1/2/px,size(Ui,2));
fy = linspace(-1/2/px,1/2/px,size(Ui,1));
[Fx, Fy] = meshgrid(fx,fy);

h1 = figure(1);   %Make figure handle (h1 refers to figure 1, even if another figure is in focus)

gif_out_filename = '../../random_lenslet_propagation_video.gif';   %Setup filename for gif



n = 0;
try
    gpuDevice;
    gpu = 1;
catch
    gpu = 0;
end

if gpu
    Ui = gpuArray(Ui);
    % Istack = gpuArray(zeros(siz(1),siz(2),length(zvec)));
end


zvec = 10;

sphase = gpuArray(sqrt(1-(lambda*Fx).^2 - (lambda*Fy).^2));
for Z = zvec
    n = n+1;
    tic
    U_out = propagate2(Ui,lambda,Z,sphase);
    toc
    I = gather(abs(U_out).^2);
    %Istack(:,:,n) = I;
    imagesc(I), axis image
    colormap('jet')
    drawnow
    
    frame = getframe(h1);   %Get data from figue 1
    image_data = frame2im(frame);   %convert data to image information (this goes straight into avi)
    [imind,cm] = rgb2ind(image_data,256);   %convert image information to index and colormap for gif (don't worry about this part)
    
    %     if n == 1;   %Make sure this is the loop index == 1
    %         imwrite(imind,cm,gif_out_filename,'gif', 'Loopcount',inf);   %If you're on the first pass, make a new gif
    %     else
    %         imwrite(imind,cm,gif_out_filename,'gif','WriteMode','append');   %If it's not the first pass, append
    %     end
    
end

%% Do spherical wave position

%mask = gather(Ui~=0);

%z0 = 1/(1/2/pzvec(1)+1/2/pzvec(end));   %Calculate sensor distance based on dioptric average
z0 = 15;
pzvec = 19.5;
for z1 = pzvec
    r = sqrt(z1^2+X.^2+Y.^2);
    Up = Ui.*1./r.*exp(1i*2*pi/lambda*r);
     U_out = propagate2(Up,lambda,z0,sphase);
     I = abs(U_out).^2;
     %autocorr = gather(real(ifftshift(ifft2(fft2(I).*conj(fft2(I))))));
    imagesc(I)
    I20 = gather(I);
    axis image
    drawnow
end
