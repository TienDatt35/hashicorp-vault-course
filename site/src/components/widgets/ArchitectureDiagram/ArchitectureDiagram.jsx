import React, { useState } from 'react';
import styles from './ArchitectureDiagram.module.css';

/**
 * <ArchitectureDiagram variant="auth-policy-secret" />
 *
 * Inline-SVG diagrams of core Vault flows. Each variant is a small
 * declarative spec: nodes (with positions), edges, and per-node explanations.
 * Click a node to see its explanation; press Play to step through the flow.
 */

const VARIANTS = {
  'auth-policy-secret': {
    title: 'Auth → Policy → Secret',
    nodes: [
      { id: 'client',  x:  60, y: 100, label: 'Client',          desc: 'Bất kỳ đối tượng nào (người dùng, ứng dụng, CI job) cần lấy secret.' },
      { id: 'auth',    x: 220, y: 100, label: 'Auth method',     desc: 'Xác thực danh tính client (userpass, AppRole, AWS, OIDC…) và cấp token.' },
      { id: 'policy',  x: 380, y: 100, label: 'Policy',          desc: 'ACL policy gắn vào token quy định đường dẫn và quyền (capabilities) được phép.' },
      { id: 'engine',  x: 540, y: 100, label: 'Secrets engine',  desc: 'KV, database, transit, PKI… trả về secret nếu policy cho phép.' },
      { id: 'secret',  x: 700, y: 100, label: 'Secret',          desc: 'Thông tin xác thực, khóa hoặc dữ liệu được trả về cho client.' },
    ],
    edges: [
      ['client', 'auth'], ['auth', 'policy'], ['policy', 'engine'], ['engine', 'secret'],
    ],
  },
  'seal-unseal': {
    title: 'Seal / Unseal',
    nodes: [
      { id: 'sealed',   x: 100, y: 100, label: 'Vault đã seal',     desc: 'Khi mới khởi động, Vault ở trạng thái sealed: chưa thể giải mã storage backend.' },
      { id: 'keys',     x: 320, y: 100, label: 'Unseal keys',       desc: 'Một số lượng tối thiểu unseal key shares (Shamir) sẽ tái tạo master key.' },
      { id: 'master',   x: 540, y: 100, label: 'Master key',        desc: 'Giải mã encryption key dùng để bảo vệ toàn bộ dữ liệu lưu trữ.' },
      { id: 'unsealed', x: 760, y: 100, label: 'Vault đã unseal',   desc: 'Vault có thể phục vụ yêu cầu. Auto-unseal thay thế bước thủ công bằng KMS.' },
    ],
    edges: [['sealed', 'keys'], ['keys', 'master'], ['master', 'unsealed']],
  },
  'token-flow': {
    title: 'Vòng đời của token',
    nodes: [
      { id: 'login',    x:  80, y: 100, label: 'Đăng nhập',  desc: 'Client xác thực qua một auth method.' },
      { id: 'token',    x: 260, y: 100, label: 'Token',      desc: 'Vault cấp token với TTL và các policy đi kèm.' },
      { id: 'use',      x: 440, y: 100, label: 'Sử dụng',    desc: 'Client truyền token qua header X-Vault-Token để đọc/ghi secret.' },
      { id: 'renew',    x: 620, y: 100, label: 'Gia hạn',    desc: 'Token có thể gia hạn được phép kéo dài tới max TTL.' },
      { id: 'revoke',   x: 800, y: 100, label: 'Thu hồi',    desc: 'Token (và tất cả lease cấp dưới nó) có thể bị thu hồi rõ ràng.' },
    ],
    edges: [['login', 'token'], ['token', 'use'], ['use', 'renew'], ['renew', 'revoke']],
  },
  'vault-key-layers': {
    title: 'Mô Hình 3 Lớp Key của Vault',
    nodes: [
      { id: 'unseal',     x:  80, y: 100, label: 'Unseal Keys',      desc: 'Các shares của root key được tạo bởi Shamir Secret Sharing. Phân phát cho operators — cần đủ threshold mới reconstruct được root key.' },
      { id: 'root',       x: 260, y: 100, label: 'Root Key',         desc: 'Reconstruct từ unseal keys. Dùng để giải mã encryption key. Không bao giờ lưu plaintext — chỉ tồn tại trong memory trong quá trình unseal rồi bị xóa.' },
      { id: 'enc',        x: 440, y: 100, label: 'Encryption Key',   desc: 'Mã hóa mọi dữ liệu bằng AES-256-GCM. Lưu trong keyring ở storage (đã encrypted bởi root key). Chỉ tồn tại dạng plaintext trong memory khi Vault unsealed.' },
      { id: 'data',       x: 620, y: 100, label: 'Data',             desc: 'Dữ liệu của bạn — secrets, policies, token metadata. Luôn được encrypt trước khi ghi ra storage. Ngay cả khi storage bị xâm phạm, không có encryption key thì không thể giải mã.' },
    ],
    edges: [['unseal', 'root'], ['root', 'enc'], ['enc', 'data']],
  },
  'vault-architecture': {
    title: 'Kiến Trúc Ba Lớp của Vault',
    nodes: [
      { id: 'client',   x:  80, y: 100, label: 'Client',            desc: 'Người dùng hoặc ứng dụng gửi request qua CLI, SDK, hoặc curl. Mọi giao tiếp đều qua HTTPS.' },
      { id: 'api',      x: 260, y: 100, label: 'HTTPS API',         desc: 'Lớp tiếp nhận request. Vault CLI chỉ là HTTP client gọi vào REST API này. Tất cả thao tác đều đi qua đây.' },
      { id: 'barrier',  x: 440, y: 100, label: 'Security Barrier',  desc: 'Ranh giới bảo vệ bao quanh Vault Core. Encrypt AES-256-GCM khi ghi ra storage, decrypt + verify khi đọc vào. Storage backend là untrusted.' },
      { id: 'core',     x: 620, y: 100, label: 'Vault Core',        desc: 'Trung tâm xử lý: thực thi ACL policy, điều phối secrets engine, auth method, audit device, và quản lý vòng đời token/lease.' },
      { id: 'storage',  x: 800, y: 100, label: 'Storage Backend',   desc: 'Lưu trữ bền vững (Raft, Consul, S3, DynamoDB…). Nằm ngoài barrier — chỉ nhận và trả ciphertext. Vault không tin tưởng backend.' },
    ],
    edges: [['client', 'api'], ['api', 'barrier'], ['barrier', 'core'], ['core', 'storage']],
  },
  'vault-components': {
    title: '4 Thành Phần Cốt Lõi của Vault',
    nodes: [
      { id: 'auth',     x:  80, y: 100, label: 'Auth Methods',     desc: 'Xác thực danh tính client (userpass, AppRole, OIDC…) và cấp token. Mặc định chỉ có token auth được enable.' },
      { id: 'token',    x: 260, y: 100, label: 'Token',            desc: 'Kết quả của mọi auth method. Token mang theo policies, TTL và permissions để truy cập secrets.' },
      { id: 'engine',   x: 440, y: 100, label: 'Secrets Engine',   desc: 'Lưu trữ (KV), sinh dynamic credentials (Database, AWS), hoặc mã hóa dữ liệu (Transit). Mỗi engine chạy tại path riêng.' },
      { id: 'storage',  x: 620, y: 100, label: 'Storage Backend',  desc: 'Nơi Vault lưu toàn bộ dữ liệu đã mã hóa (AES-256). Mỗi cluster chỉ có 1 backend; Raft và Consul hỗ trợ HA.' },
      { id: 'audit',    x: 440, y: 220, label: 'Audit Devices',    desc: 'Ghi log mọi request/response dạng JSON. Sensitive data bị hash HMAC-SHA256. Nếu không ghi được, Vault từ chối request.' },
    ],
    edges: [['auth', 'token'], ['token', 'engine'], ['engine', 'storage'], ['engine', 'audit']],
  },
};

export default function ArchitectureDiagram({ variant = 'auth-policy-secret' }) {
  const spec = VARIANTS[variant];
  const [selected, setSelected] = useState(spec.nodes[0].id);
  const [playing, setPlaying] = useState(false);

  function play() {
    if (playing) return;
    setPlaying(true);
    spec.nodes.forEach((node, i) => {
      setTimeout(() => {
        setSelected(node.id);
        if (i === spec.nodes.length - 1) setPlaying(false);
      }, i * 900);
    });
  }

  const selectedNode = spec.nodes.find((n) => n.id === selected);

  return (
    <div className={styles.wrap}>
      <div className={styles.header}>
        <strong>{spec.title}</strong>
        <button className={styles.play} onClick={play} disabled={playing}>
          {playing ? 'Đang chạy…' : '▶ Phát'}
        </button>
      </div>
      <svg viewBox="0 0 880 200" className={styles.svg} role="img" aria-label={spec.title}>
        {spec.edges.map(([from, to], i) => {
          const a = spec.nodes.find((n) => n.id === from);
          const b = spec.nodes.find((n) => n.id === to);
          return (
            <line
              key={i}
              x1={a.x + 60} y1={a.y}
              x2={b.x - 60} y2={b.y}
              className={styles.edge}
              markerEnd="url(#arrow)"
            />
          );
        })}
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5"
                  markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="currentColor" />
          </marker>
        </defs>
        {spec.nodes.map((n) => (
          <g
            key={n.id}
            className={`${styles.node} ${selected === n.id ? styles.nodeActive : ''}`}
            onClick={() => setSelected(n.id)}
            transform={`translate(${n.x}, ${n.y})`}
          >
            <rect x={-58} y={-26} width={116} height={52} rx={8} />
            <text textAnchor="middle" dominantBaseline="middle">{n.label}</text>
          </g>
        ))}
      </svg>
      <div className={styles.detail}>
        <strong>{selectedNode.label}.</strong> {selectedNode.desc}
      </div>
    </div>
  );
}
