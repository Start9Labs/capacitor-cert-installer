declare module '@capacitor/core' {
  interface PluginRegistry {
    CertInstaller: CertInstallerPlugin;
  }
}

export interface CertInstallerPlugin {
  installCert(options: { value: string, name?: string, port?: number }): Promise<void>;
}
