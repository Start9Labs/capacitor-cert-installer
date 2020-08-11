import { WebPlugin } from '@capacitor/core';
import { CertInstallerPlugin } from './definitions';

export class CertInstallerWeb extends WebPlugin implements CertInstallerPlugin {
  constructor() {
    super({
      name: 'CertInstaller',
      platforms: ['web'],
    });
  }

  async installCert(options: { value: string, name?: string }): Promise<void> {
    let element = document.createElement('a');
    const dataUrl = 'data:application/x-x509-ca-cert,' + encodeURIComponent(options.value);
    element.setAttribute('href', dataUrl);
    element.setAttribute('download', `${name || 'CA'}.crt`);
    element.style.display = 'none';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
  }
}

const CertInstaller = new CertInstallerWeb();

export { CertInstaller };

import { registerWebPlugin } from '@capacitor/core';
registerWebPlugin(CertInstaller);
