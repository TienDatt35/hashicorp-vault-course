import React, { useState } from 'react';
import styles from './Flowchart.module.css';

/**
 * <Flowchart title="..." tree={node} />
 *
 * A node is one of:
 *   { question: string, options: [{ label, next: <node> }, ...] }
 *   { result: string, detail?: string }
 *
 * Walks the learner through a decision tree, e.g. "Which auth method should I use?"
 */
export default function Flowchart({ title, tree }) {
  const [path, setPath] = useState([tree]);

  const current = path[path.length - 1];
  const isResult = !!current.result;

  function choose(option) {
    setPath((p) => [...p, option.next]);
  }
  function back() {
    if (path.length > 1) setPath((p) => p.slice(0, -1));
  }
  function reset() {
    setPath([tree]);
  }

  return (
    <div className={styles.wrap}>
      {title && <div className={styles.title}>{title}</div>}

      {!isResult && (
        <>
          <p className={styles.question}>{current.question}</p>
          <div className={styles.options}>
            {current.options.map((opt, i) => (
              <button key={i} className={styles.option} onClick={() => choose(opt)}>
                {opt.label}
              </button>
            ))}
          </div>
        </>
      )}

      {isResult && (
        <div className={styles.result}>
          <strong>{current.result}</strong>
          {current.detail && <p>{current.detail}</p>}
        </div>
      )}

      <div className={styles.controls}>
        {path.length > 1 && (
          <button className={styles.linkBtn} onClick={back}>← Quay lại</button>
        )}
        {path.length > 1 && (
          <button className={styles.linkBtn} onClick={reset}>Bắt đầu lại</button>
        )}
      </div>
    </div>
  );
}
