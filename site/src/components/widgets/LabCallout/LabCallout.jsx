import React from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './LabCallout.module.css';

/**
 * <LabCallout
 *   labId="01-fundamentals/01-dev-server-first-steps"
 *   title="Your first dev server"
 *   estMinutes={15}
 * />
 *
 * Renders a styled card with an "Open in Codespaces" button that points at the
 * lab's per-folder devcontainer. Org/repo come from docusaurus.config.js
 * customFields so a fork only needs to update one place.
 */
export default function LabCallout({ labId, title, estMinutes }) {
  const { siteConfig } = useDocusaurusContext();
  const { githubOrg, githubRepo } = siteConfig.customFields || {};

  const codespacesUrl =
    `https://codespaces.new/${githubOrg}/${githubRepo}` +
    `?devcontainer_path=labs/${labId}/.devcontainer/devcontainer.json`;

  const repoUrl = `https://github.com/${githubOrg}/${githubRepo}/tree/main/labs/${labId}`;

  return (
    <div className={styles.card}>
      <div className={styles.head}>
        <span className={styles.tag}>BÀI THỰC HÀNH</span>
        <span className={styles.title}>{title}</span>
        {estMinutes != null && (
          <span className={styles.time}>~{estMinutes} phút</span>
        )}
      </div>
      <div className={styles.actions}>
        <a className={styles.primary} href={codespacesUrl} target="_blank" rel="noreferrer">
          Mở trong Codespaces
        </a>
        <a className={styles.secondary} href={repoUrl} target="_blank" rel="noreferrer">
          Xem trên GitHub
        </a>
      </div>
    </div>
  );
}
